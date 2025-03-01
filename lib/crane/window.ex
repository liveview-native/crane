defmodule Crane.Window do
  alias Crane.Window.{History, ViewTree}
  alias HttpCookie.Jar

  defstruct history: %History{},
    view_tree: %ViewTree{},
    response: nil,
    pid: nil,
    cookie_jar: Jar.new(),
    sockets: []

  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [])
  end

  @impl true
  def init(_) do
    window = %__MODULE__{
      pid: self()
    }

    {:ok, window}
  end

  @impl true
  def handle_call(:get, _from, window),
    do: {:reply, window, window}

  def handle_call({:fetch, options}, _from, %__MODULE__{history: history, cookie_jar: cookie_jar} = window) do
    options
    |> Keyword.validate([url: nil, method: "GET", headers: [], body: nil])
    |> case do
      {:ok, options} ->
        {_request, response} =
          options
          |> Keyword.merge(Application.get_env(:crane, :fetch_req_options, []))
          |> Req.new()
          |> HttpCookie.ReqPlugin.attach()
          |> Req.Request.merge_options([cookie_jar: cookie_jar])
          |> Req.run!()

        history = with "GET" <- Keyword.get(options, :method),
          {:ok, _frame, history} <- History.push_state(history, %{}, options) do
            history
          else
            _error ->
              history
          end

        %{private: %{cookie_jar: cookie_jar}} = response

        window = %{window | history: history, response: response, cookie_jar: cookie_jar}

        {:reply, {:ok, window}, window}

      {:error, invalid_options} ->
        {:reply, {:invalid_options, invalid_options}, window}
    end
  end

  def handle_call({:create_socket, options}, _from, %__MODULE__{history: history, cookie_jar: cookie_jar} = window) do
    options
    |> Keyword.validate([url: nil, headers: []])
    |> case do
      {:ok, options} ->
        nil
      {:error, invalid_options} ->
        {:reply, {:invalid_options, invalid_options}, window}
    end
  end

  def new do
    {:ok, pid} = start_link(nil)
    {:ok, GenServer.call(pid, :get)}
  end

  def close(window) do
    GenServer.stop(window.pid, :normal)
  end

  def open do
    start_link([])
  end

  def fetch(%__MODULE__{pid: pid}, options) do
    GenServer.call(pid, {:fetch, options})
  end

  def close() do

  end

  def create_socket(%__MODULE__{pid: pid}, options) do
    GenServer.call(pid, {:create_socket, options})
  end
end
