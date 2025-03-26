defmodule Crane.GRPC.Socket do
  use GRPC.Server, service: Crane.Protos.Browser.Window.SocketService.Service
  alias Crane.{
    Protos,
    Browser.Window,
    Browser.Window.WebSocket,
  }

  def send(request, _stream) do
    {:ok, socket} = WebSocket.get(request.socket_name)
    type = String.to_existing_atom(request.type)
    :ok = WebSocket.send(socket, {type, request.data})
  end

  def receive(request, stream) do
    IO.inspect(stream)
    {:ok, socket} = WebSocket.get(request.name)

    :ok = WebSocket.attach_receiver(socket, fn([{type, data}]) ->
      msg = %Protos.Browser.Window.Socket.Message {
        type: Atom.to_string(type),
        data: data
      }

      receive do
        {:EXIT, _pid, reason} ->
          :ok
      end
      GRPC.Server.send_reply(stream, msg)
    end)

    wait_forever()
  end

  defp wait_forever do
    receive do
      :stop -> :ok
    after
      1000 -> wait_forever()
    end
  end

  def new(request, _stream) do
    {:ok, window} = Window.get(String.to_existing_atom(request.window_name))

    options =
      request
      |> Map.take([:url])
      |> Map.to_list()

    {:ok, socket, _window} = Window.new_socket(window, options) 

    WebSocket.to_protoc(socket)
  end
end
