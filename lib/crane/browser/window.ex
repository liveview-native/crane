defmodule Crane.Browser.Window do
  use GenServer

  alias Crane.{
    Browser,
    Fuse
  }
  alias Crane.Browser.Window.{
    History,
    Logger,
    WebSocket
  }
  # alias Crane.Browser
  # alias Crane.Browser.Window.{History, Logger, ViewTree, WebSocket}
  # alias Crane.Protos

  import Crane.Utils

  defstruct name: nil,
    history: %History{},
    logger: nil,
    browser_name: nil,
    view_trees: %{},
    stylesheets: [],
    response: nil,
    created_at: nil,
    refs: %{}

  def start_link(args) when is_list(args) do
    name = generate_name(:window)
    GenServer.start_link(__MODULE__, [{:name, name} | args], name: name)
  end

  def start_link(state) when is_map(state) do
    state =
      state
      |> Map.get_and_update(:name, fn
        invalid when invalid in ["", nil]-> {invalid, generate_name(:window)}
        name -> {name, name}
      end)
      |> elem(1)
      |> Map.take([:history, :name, :response, :view_tree, :browser_name])

    GenServer.start_link(__MODULE__, state, name: state.name)
  end

  @impl true
  def init(args) when is_list(args) do
    window = %__MODULE__{
      name: args[:name],
      created_at: DateTime.now!("Etc/UTC"),
      browser_name: args[:browser].name
    }
    {:ok, logger} = Logger.new(window: window)

    Process.flag(:trap_exit, true)
    {:ok, %__MODULE__{window | logger: logger}}
  end

  def init(state) when is_map(state) do
    window = struct(__MODULE__, state)
    {:ok, logger} = Logger.new(window: window)
    Process.flag(:trap_exit, true)
    {:ok, %__MODULE__{window | logger: logger}}
  end

  @impl true
  def handle_call(:get, _from, window),
    do: {:reply, {:ok, window}, window}

  def handle_call({:monitor, pid}, _from, window) do
    Process.monitor(pid)
    {:reply, window, window}
  end

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

        broadcast(window.name, {:fetch, window, response})
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

        window =
          %{window | history: history, response: response}
          |> Map.merge(Fuse.run_middleware(:visit, response))

        {:reply, {:ok, response, window}, window}

      error -> error
    end
  end

  def handle_call({:go, offset}, from, %__MODULE__{history: history} = window) do
    with {:ok, {_state, options} = _frame, history} <- History.go(history, offset),
      {:reply, {:ok, response, window}, _window} <- handle_call({:fetch, options}, from, %__MODULE__{window | history: history}),
      {:ok, options} <- Keyword.validate(options, [url: nil, method: "GET", headers: [], body: nil]),
      "GET" <- Keyword.get(options, :method) do
        window = %__MODULE__{window | response: response}
        {:reply, {:ok, response, window}, window}
    else
      error -> error
    end
  end

  def handle_call({:new_socket, options}, _from, %__MODULE__{name: name, refs: refs} = window) do
    with {:ok, options} <- Keyword.validate(options, [url: nil, headers: [], window_name: nil]),
      {_, options} <- normalize_options(options),
      {:ok, socket} <- WebSocket.new(window, options) do
        refs = monitor(socket, refs)
        window = %__MODULE__{window | refs: refs}
        broadcast(name, {:new_socket, window, socket})

        {:reply, {:ok, socket, window}, window}
    else
      {:error, error} ->
        {:reply, error, window}
      error ->
        {:reply, error, window}
    end
  end

  def handle_call(:sockets, _from, %__MODULE__{refs: refs} = window) do
    sockets = get_reference_resource(refs, :socket, fn(name) ->
      WebSocket.get(name)
    end)
    |> Enum.sort_by(&(&1.created_at), {:asc, DateTime})

    {:reply, {:ok, sockets}, window}
  end

  defp normalize_options(options) do
    Keyword.get_and_update(options, :url, fn 
     "localhost" <> _tail = url -> {url, "http://" <> url}
      url -> {url, url}
    end)
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %__MODULE__{refs: refs} = window) do
    case Map.pop(refs, ref) do
      {nil, _refs} ->
        {:noreply, window}
      {_name, refs} -> 
        {:noreply, %__MODULE__{window | refs: refs}}
    end
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def new(args) when is_list(args) do
    with {:ok, pid} <- start_link(args),
      {:ok, window} <- GenServer.call(pid, :get) do
        {:ok, window}
    else
      error -> {:error, error}
    end
  end

  def restore(%__MODULE__{} = state) do
    with {:ok, pid} <- start_link(state),
      {:ok, window} <- GenServer.call(pid, :get) do
        {:ok, window}
    else
      error -> {:error, error}
    end
  end

  def close(%__MODULE__{name: name}) do
    GenServer.stop(name, :normal)
  end

  def get(%__MODULE__{name: name}),
    do: get(name)

  def get(name) when is_binary(name),
    do: get(String.to_existing_atom(name))

  def get(name) when is_atom(name) do
    GenServer.call(name, :get)
  end

  def get!(resource_or_name) do
    {:ok, window} = get(resource_or_name)
    window
  end

  def fetch(%__MODULE__{name: name}, options) do
    GenServer.call(name, {:fetch, options})
  end

  def visit(%__MODULE__{name: name}, options) do
    GenServer.call(name, {:visit, options})
  end

  def forward(%__MODULE__{name: name}) do
    GenServer.call(name, {:go, 1}, :infinity)
  end

  def back(%__MODULE__{name: name}) do
    GenServer.call(name, {:go, -1})
  end

  def go(%__MODULE__{name: name}, offset) do
    GenServer.call(name, {:go, offset})
  end

  def new_socket(%__MODULE__{name: name}, options) do
    options = Keyword.put(options, :window_name, name)
    GenServer.call(name, {:new_socket, options})
  end

  def sockets(%__MODULE__{name: name}) do
    GenServer.call(name, :sockets)
  end

  def sockets!(window) do
    {:ok, sockets} = sockets(window)
    sockets
  end
end
