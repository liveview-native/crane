defmodule Crane.Browser.Window.WebSocket do
  use GenServer

  alias Crane.{
    Protos,
    Browser.Window
  }

  import Crane.Utils, only: [
    generate_name: 1
  ]

  defstruct conn: nil,
    window_name: nil,
    ref: nil,
    websocket: nil,
    name: nil,
    receiver: nil

  def start_link(opts) when is_list(opts) do
    opts =
      Keyword.put_new_lazy(opts, :name, fn ->
        generate_name(:socket)
      end)

    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def init(opts) do
    Process.flag(:trap_exit, true)
    uri = URI.parse(opts[:url])

    scheme = String.to_atom(uri.scheme)

    with {:ok, opts} = Keyword.validate(opts, [url: nil, headers: [], window_name: nil, name: nil]),
      {:ok, conn} <- Mint.HTTP1.connect(scheme, uri.host, uri.port),
      {:ok, conn, ref} <- Mint.WebSocket.upgrade(ws_scheme(scheme), conn, ws_path(uri.path), opts[:headers]),
      http_reply_message <- receive(do: (message -> message)),
      {:ok, conn, responses} <- Mint.WebSocket.stream(conn, http_reply_message),
      responses <- parse_stream_responses(responses, ref),
      {:ok, conn, websocket} <- Mint.WebSocket.new(conn, ref, responses[:status], responses[:headers]) do
        socket = %__MODULE__{
          conn: conn,
          ref: ref,
          websocket: websocket,
          window_name: opts[:window_name],
          name: opts[:name]
        } 

        {:ok, socket}
      else
        {:error, error} ->
          {:stop, {:shutdown, error}}
        error ->
          {:stop, {:shutdown, error}}
      end
  end

  defp parse_stream_responses(responses, ref) do
    Enum.reduce(responses, [], fn
      {:status, ^ref, status}, acc -> [{:status, status} | acc] 
      {:headers, ^ref, headers}, acc -> [{:headers, headers} | acc]
      _other, acc -> acc
    end)
  end

  def handle_call(:get, _from, socket) do
    {:reply, {:ok, socket}, socket}
  end

  def handle_call({:attach_receiver, receiver}, _from, socket) when is_function(receiver) do
    {:reply, :ok, %__MODULE__{socket | receiver: receiver}}
  end

  def handle_call(_msg, _from, socket) do
    {:noreply, socket}
  end

  def handle_cast({:send, msg}, %__MODULE__{websocket: websocket, conn: conn, ref: ref} = socket) do
    {:ok, websocket, data} = Mint.WebSocket.encode(websocket, msg)
    {:ok, conn} = Mint.WebSocket.stream_request_body(conn, ref, data)

    {:noreply, %__MODULE__{socket | websocket: websocket, conn: conn}}
  end

  def handle_cast(:disconnect, %__MODULE__{conn: conn} = socket) do
    {:ok, conn} = Mint.HTTP.close(conn)

    {:stop, :normal, %__MODULE__{socket | conn: conn}}
  end

  def handle_cast(_msg, socket) do
    {:noreply, socket}
  end

  def handle_info({protocol, _, _data} = msg, %__MODULE__{websocket: websocket, conn: conn, ref: ref, receiver: receiver} = socket) when protocol in [:ssl, :tcp] do
    {:ok, conn, [{:data, ^ref, data}]} = Mint.WebSocket.stream(conn, msg)
    {:ok, websocket, msg} = Mint.WebSocket.decode(websocket, data)

    if receiver do
      receiver.(msg)
    else
      IO.inspect(msg, label: "Unhandled message received")
    end

    {:noreply, %__MODULE__{socket | websocket: websocket, conn: conn}}
  end

  def handle_info({closed_protocol, _}, %__MODULE__{conn: conn} = socket) when closed_protocol in [:tcp_closed, :ssl_closed] do
    {:ok, conn} = Mint.HTTP.close(conn)

    {:stop, :normal, %__MODULE__{socket | conn: conn}}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp ws_scheme(:http),
    do: :ws
  defp ws_scheme(:https),
    do: :wss

  defp ws_path(nil),
    do: "/"
  defp ws_path(path),
    do: path

  def send(%__MODULE__{name: name}, msg) do
    GenServer.cast(name, {:send, msg})
  end

  def close(%__MODULE__{name: name}) do
    GenServer.cast(name, :disconnect)
  end

  def new(%Window{name: window_name}, options) when is_list(options) do
    with options <- Keyword.put(options, :window_name, window_name),
      {:ok, pid} <- start_link(options),
      {:ok, socket} <- GenServer.call(pid, :get) do
        {:ok, socket}
    else
      error ->
        {:error, error}
    end
  end

  def get(%__MODULE__{name: name}),
    do: get(name)

  def get(name) when is_binary(name),
    do: get(String.to_existing_atom(name))

  def get(name) when is_atom(name) do
    GenServer.call(name, :get)
  end

  def attach_receiver(%__MODULE__{name: name}, receiver) when is_function(receiver) do
    GenServer.call(name, {:attach_receiver, receiver})
  end

  def to_protoc(%__MODULE__{} = web_socket) do
    %Protos.Browser.Window.Socket{
      name: Atom.to_string(web_socket.name),
      window_name: Atom.to_string(web_socket.window_name)
    }
  end
end
