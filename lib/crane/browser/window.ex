defmodule Crane.Browser.Window do
  alias Crane.{
    Browser,
    Fuse
  }
  alias Crane.Browser.Window.{
    History,
    Location,
    Logger,
    WebSocket
  }

  use Crane.Object,
    history: %History{},
    logger: nil,
    owner: Browser,
    view_trees: %{
      document: [],
      body: [],
      loading: [],
      disconnected: [],
      reconnecting: [],
      error: []
    },
    location: %Location{},
    stylesheets: [],
    response: nil,
    scripts: []

  defchild socket: WebSocket
  
  @impl true
  def handle_continue({:init, _opts}, window) do
    {:noreply, %__MODULE__{window |
      logger: Logger.new!(window: window)
    }}
  end

  def handle_continue({:run_scripts, opts}, %__MODULE__{scripts: scripts} = window) do
    Enum.each(scripts, &(GenServer.cast(Crane, {:run_script, &1, window, opts})))

    {:noreply, window}
  end

  def handle_continue(_continue_arg, window),
    do: {:noreply, window}

  def handle_call({:fetch, options}, _from, %__MODULE__{} = window) do
    options
    |> Keyword.validate([url: nil, method: "GET", headers: [], body: nil])
    |> case do
      {:ok, options} ->
        {:ok, %Browser{} = browser} = Browser.get(window.browser_name)
        {_request, response} =
          options
          |> Keyword.update(:url, nil, &String.trim(&1))
          |> Keyword.put(:headers, browser.headers ++ options[:headers])
          |> Keyword.merge(Application.get_env(:crane, :fetch_req_options, []))
          |> Req.new()
          |> HttpCookie.ReqPlugin.attach()
          |> Req.Request.merge_options([cookie_jar: browser.cookie_jar])
          |> Req.run!()

        %{private: %{cookie_jar: cookie_jar}} = response

        :ok = Browser.update_cookie_jar(browser, cookie_jar)

        {:reply, {:ok, response, window}, window}

      {:error, invalid_options} ->
        {:reply, {:invalid_options, invalid_options}, window}
    end

  rescue
    error ->
      response = %Req.Response{
        status: 400,
        body: Exception.message(error)
      }

      {:reply, {:ok, response, window}, window}
  end

  def handle_call({:visit, options}, from, window) do
    {receiver, options} = Keyword.pop(options, :receiver)
    case handle_call({:fetch, options}, from, window) do
      {:reply, {:ok, response, window}, _window} -> 
        history =
          with {:ok, options} <- Keyword.validate(options, [url: nil, method: "GET", headers: [], body: nil]),
            "GET" <- Keyword.get(options, :method),
            {:ok, _frame, history} <- History.push_state(window.history, %{}, options) do
              history
          else
            _error ->  window.history
          end

        location = Location.new(options[:url])

        window =
          %{window | history: history, response: response, location: location}
          |> Map.merge(Fuse.run_middleware(:visit, response))

        # :ok = GenServer.cast(window.name, {:run_scripts, receiver: receiver})

        Crane.Utils.broadcast(Crane, {:update, window})

        {:reply, {:ok, window}, window, {:continue, {:run_scripts, receiver: receiver}}}

      error -> error
    end
  end

  def handle_call({:go, offset}, from, %__MODULE__{history: history} = window) do
    with {:ok, {_state, options} = _frame, history} <- History.go(history, offset),
      {:reply, {:ok, response, window}, _window} <- handle_call({:fetch, options}, from, %__MODULE__{window | history: history}),
      {:ok, options} <- Keyword.validate(options, [url: nil, method: "GET", headers: [], body: nil]),
      "GET" <- Keyword.get(options, :method) do
        window = %__MODULE__{window | response: response}
        {:reply, {:ok,  window}, window}
    else
      error -> error
    end
  end

  def handle_call({:monitor, resource}, _from, %__MODULE__{refs: refs} = window) do
    refs = Crane.Utils.monitor(resource, refs)
    window = %__MODULE__{window | refs: refs}

    {:reply, {:ok, window}, window}
  end

  # @impl true
  # def handle_cast({:run_scripts, opts}, %__MODULE__{scripts: scripts} = window) do
  #   {:noreply, Enum.reduce(scripts, window, &(&1.call(&2, opts)))}
  # end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def restore(%__MODULE__{} = state) do
    opts = Map.to_list(state) |> Keyword.drop([:__struct__, :refs])
    with {:ok, pid} <- start_link(opts),
      {:ok, window} <- GenServer.call(pid, :get) do
        {:ok, window}
    else
      error -> {:error, error}
    end
  end

  def fetch(%__MODULE__{name: name}, options),
    do: GenServer.call(name, {:fetch, options})

  def visit(%__MODULE__{name: name}, options) do
    {:ok, window} = GenServer.call(name, {:visit, options})
    {:ok, window}
  end

  def forward(%__MODULE__{name: name}),
    do: GenServer.call(name, {:go, 1}, :infinity)

  def back(%__MODULE__{name: name}),
    do: GenServer.call(name, {:go, -1})

  def go(%__MODULE__{name: name}, offset),
    do: GenServer.call(name, {:go, offset})

  def monitor(%__MODULE__{name: name}, resource),
    do: GenServer.call(name, {:monitor, resource})

  def headers(%__MODULE__{browser_name: browser_name} = window) do
    {:ok, browser} = Browser.get(browser_name)
    request_url = URI.parse(window.location.href)
    {:ok, cookie, _jar} = HttpCookie.Jar.get_cookie_header_value(browser.cookie_jar, request_url)
    browser.headers ++ [{"cookie", cookie}]
  end

  def strip!(%__MODULE__{} = window),
    do: %{
      name: window.name,
      stylesheets: window.stylesheets,
      browser_name: window.browser_name,
      view_trees: Map.drop(window.view_trees, [:document, :body])
    }
end
