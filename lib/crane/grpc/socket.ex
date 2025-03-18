defmodule Crane.GRPC.Socket do
  use GRPC.Server, service: Crane.Protos.Browser.Window.SocketService.Service
  alias Crane.{
    Browser.Window,
    Browser.Window.History,
    Browser.Window.WebSocket,
    Protos
  }

  def send(request, _stream) do
    {:ok, socket} = WebSocket.get(request.socket_name)
    type = String.to_existing_atom(request.type)
    :ok = WebSocket.send(socket, {type, request.data})
  end

  def receive(request, stream) do
    {:ok, socket} = WebSocket.get(request.name)
    :ok = WebSocket.attach_receiver(socket, stream)

    stream
  end
end
