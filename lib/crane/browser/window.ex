defmodule Crane.Browser.Window do
  alias Crane.Browser
  alias Crane.Browser.Window.{History, ViewTree}
  alias Crane.Protos

  defstruct history: %History{},
    browser_name: nil,
    view_tree: %ViewTree{},
    response: nil,
    name: nil,
    sockets: []

  use GenServer

  def start_link(state) when is_map(state) do
    name = Map.get_lazy(state, :name, fn ->
      "window-" <>
      (:crypto.hash(:sha, "#{:erlang.system_time(:nanosecond)}")
      |> Base.encode32(case: :lower))
      |> String.to_atom()
    end)

    state =
      state
      |> Map.put(:name, name)
      |> Map.take([:history, :name, :response, :view_tree])

    GenServer.start_link(__MODULE__, state, name: name)
  end

  @impl true
  def init(state) do
    {:ok, struct(__MODULE__, state)}
  end

  @impl true
  def handle_call(:get, _from, window),
    do: {:reply, {:ok, window}, window}

  def handle_call({:fetch, options}, _from, window) do
    options
    |> Keyword.validate([url: nil, method: "GET", headers: [], body: nil])
    |> case do
      {:ok, options} ->
        {:ok, %Browser{} = browser} = Browser.get()
        {_request, response} =
          options
          |> Keyword.put(:headers, browser.headers ++ options[:headers])
          |> Keyword.merge(Application.get_env(:crane, :fetch_req_options, []))
          |> Req.new()
          |> HttpCookie.ReqPlugin.attach()
          |> Req.Request.merge_options([cookie_jar: browser.cookie_jar])
          |> Req.run!()

        %{private: %{cookie_jar: cookie_jar}} = response

        :ok = Browser.update_cookie_jar(cookie_jar)

        {:reply, {:ok, response, window}, window}

      {:error, invalid_options} ->
        {:reply, {:invalid_options, invalid_options}, window}
    end
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

        window = %{window | history: history, response: response}

        {:reply, {:ok, response, window}, window}

      error -> error
    end
  end

  def handle_call({:create_socket, options}, _from, %__MODULE__{history: _history} = window) do
    options
    |> Keyword.validate([url: nil, headers: []])
    |> case do
      {:ok, _options} ->
        nil
      {:error, invalid_options} ->
        {:reply, {:invalid_options, invalid_options}, window}
    end
  end

  def new(state \\ %{}) when is_map(state) do
    with {:ok, pid} <- start_link(state),
      {:ok, window} <- GenServer.call(pid, :get) do
        {:ok, window}
    else
      error -> {:error, error}
    end
  end

  def close(window) do
    GenServer.stop(window.name, :normal)
  end

  def get(name) when is_binary(name),
    do: get(String.to_atom(name))

  def get(name) when is_atom(name) do
    GenServer.call(name, :get)
  end

  def open do
    start_link([])
  end

  def fetch(%__MODULE__{name: name}, options) do
    GenServer.call(name, {:fetch, options})
  end

  def visit(%__MODULE__{name: name}, options) do
    GenServer.call(name, {:visit, options})
  end

  def close() do

  end

  def create_socket(%__MODULE__{name: name}, options) do
    GenServer.call(name, {:create_socket, options})
  end

  def to_proto(%__MODULE__{name: name}) do
    %Protos.Browser.Window{name: Atom.to_string(name)}
  end
end
