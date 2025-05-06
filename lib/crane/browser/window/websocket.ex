defmodule Crane.Browser.Window.WebSocket do
  alias Crane.Browser.Window

  use Crane.Object,
    name_prefix: :socket,
    conn: nil,
    ref: nil,
    owner: Window,
    socket: nil,
    receiver: nil

  def init(opts) do
    {:ok, websocket, {:continue, {:init, opts}}} = super(opts)
    {:ok, opts} = Keyword.validate(opts, [url: nil, headers: []])

    opts = Keyword.update(opts, :url, nil, fn 
     "localhost" <> _tail = url -> "http://" <> url
      url -> url
    end)

    uri = URI.parse(opts[:url])

    with {:ok, conn} <- Mint.HTTP.connect(http_scheme(uri), uri.host, uri.port),
      {:ok, conn, ref} <- Mint.WebSocket.upgrade(ws_scheme(uri), conn, ws_path(uri), opts[:headers]),
      http_reply_message <- receive(do: (message -> message)),
      {:ok, conn, responses} <- Mint.WebSocket.stream(conn, http_reply_message),
      responses <- parse_stream_responses(responses, ref),
      {:ok, conn, socket} <- Mint.WebSocket.new(conn, ref, responses[:status], responses[:headers]) do
        websocket = %__MODULE__{websocket |
          conn: conn,
          ref: ref,
          socket: socket,
        } 

        {:ok, websocket}
    else
      {:error, error} ->
        {:stop, {:shutdown, error}}
      error ->
        {:stop, {:shutdown, error}}
    end
  end

  defp http_scheme(%URI{scheme: scheme}) do
    case scheme do
      "ws" -> "http"
      "wss" -> "https"
      scheme -> scheme
    end
    |> String.to_atom()
  end

  defp ws_scheme(%URI{scheme: scheme}) do
    case scheme do
      "http" -> "ws"
      "https" -> "wss"
      scheme -> scheme
    end
    |> String.to_atom()
  end

  defp ws_path(%URI{path: nil}),
    do: "/"
  defp ws_path(%URI{path: path}),
    do: path

  defp parse_stream_responses(responses, ref) do
    Enum.reduce(responses, [], fn
      {:status, ^ref, status}, acc -> [{:status, status} | acc] 
      {:headers, ^ref, headers}, acc -> [{:headers, headers} | acc]
      _other, acc -> acc
    end)
  end

  def handle_call({:attach_receiver, receiver}, _from, websocket) do
    {:reply, :ok, %__MODULE__{websocket | receiver: receiver}}
  end

  def handle_call(_msg, _from, websocket) do
    {:noreply, websocket}
  end

  def handle_cast({:send, msg}, %__MODULE__{socket: socket, conn: conn, ref: ref} = websocket) do
    {:ok, socket, data} = Mint.WebSocket.encode(socket, msg)
    {:ok, conn} = Mint.WebSocket.stream_request_body(conn, ref, data)

    {:noreply, %__MODULE__{websocket | socket: socket, conn: conn}}
  end

  def handle_cast(:disconnect, %__MODULE__{conn: conn} = websocket) do
    {:ok, conn} = Mint.HTTP.close(conn)

    {:stop, :normal, %__MODULE__{websocket | conn: conn}}
  end

  def handle_cast(_msg, websocket) do
    {:noreply, websocket}
  end

  def handle_info({protocol, _, _data} = msg, %__MODULE__{socket: socket, conn: conn, ref: ref, receiver: receiver} = websocket) when protocol in [:ssl, :tcp] do
    {:ok, conn, [{:data, ^ref, data}]} = Mint.WebSocket.stream(conn, msg)
    {:ok, socket, msg} = Mint.WebSocket.decode(socket, data)

    if receiver do
      Kernel.send(receiver, msg)
    end

    {:noreply, %__MODULE__{websocket | socket: socket, conn: conn}}
  end

  def handle_info({closed_protocol, _}, %__MODULE__{conn: conn} = websocket) when closed_protocol in [:tcp_closed, :ssl_closed] do
    {:ok, conn} = Mint.HTTP.close(conn)

    {:stop, :normal, %__MODULE__{websocket | conn: conn}}
  end

  def handle_info(_msg, websocket) do
    {:noreply, websocket}
  end

  def send(%__MODULE__{name: name}, msg) do
    GenServer.cast(name, {:send, msg})
  end

  def close(%__MODULE__{name: name}) do
    GenServer.cast(name, :disconnect)
  end

  def attach_receiver(%__MODULE__{name: name}, receiver) do
    GenServer.call(name, {:attach_receiver, receiver})
  end
end
