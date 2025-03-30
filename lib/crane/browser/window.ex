defmodule Crane.Browser.Window do
  use GenServer

  alias Crane.Browser
  alias Crane.Browser.Window.{History, ViewTree, WebSocket}
  alias Crane.Protos

  import Crane.Utils

  defstruct name: nil,
    history: %History{},
    browser_name: nil,
    view_tree: %ViewTree{},
    response: nil,
    refs: %{}

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
  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, struct(__MODULE__, state)}
  end

  @impl true
  def handle_call(:get, _from, window),
    do: {:reply, {:ok, window}, window}

  def handle_call({:monitor, pid}, _from, window) do
    Process.monitor(pid)
    {:reply, window, window}
  end

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

        window = %{window | history: history, response: response}

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

  def handle_call({:new_socket, options}, _from, %__MODULE__{refs: refs} = window) do
    with {:ok, options} <- Keyword.validate(options, [url: nil, headers: [], window_name: nil]),
      {_, options} <- normalize_options(options),
    {:ok, socket} <- WebSocket.new(window, options),
    refs <- monitor(socket, refs) do
      window = %__MODULE__{window | refs: refs}
      {:reply, {:ok, socket, window}, window}
    else
      {:error, error} ->
        {:reply, error, window}
      error ->
        {:reply, error, window}
    end
  end

  def handle_call(:sockets, _from, %__MODULE__{refs: refs} = window) do
    sockets = Enum.reduce(refs, [], fn
      {_ref, "socket-" <> _id = name}, acc ->
        {:ok, socket} = Crane.Browser.Window.WebSocket.get(%Crane.Browser.Window.WebSocket{name: name})
        [socket | acc]
      _other, acc -> acc
    end)

    {:reply, {:ok, sockets}, window}
  end

  defp normalize_options(options) do
    Keyword.get_and_update(options, :url, fn 
     "localhost" <> _tail = url -> {url, "http://" <> url}
      url -> {url, url}
    end)
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{refs: refs} = window) do
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

  def get(%__MODULE__{name: name}),
    do: get(name)

  def get(name) when is_binary(name),
    do: get(String.to_existing_atom(name))

  def get(name) when is_atom(name) do
    GenServer.call(name, :get)
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

  def to_proto(%__MODULE__{name: name, refs: refs}) do
    %Protos.Browser.Window{
      name: Atom.to_string(name),
      sockets: get_reference_names(refs, :socket)
    }
  end
end
