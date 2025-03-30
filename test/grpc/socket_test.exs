defmodule Crane.GRPC.SocketTest do
  use GRPC.Integration.TestCase

  alias Crane.Browser.{
    Window,
    Window.WebSocket
  }
  alias Crane.GRPC.Socket, as: Server
  alias Crane.Protos.Browser.Window.SocketService.Stub, as: Client
  alias Crane.Protos

  setup do
    {:ok, window_pid} = Window.start_link(%{})
    {:ok, window} = GenServer.call(window_pid, :get)

    on_exit fn ->
      Process.exit(window_pid, :normal)
    end

    {:ok, window: window}
  end

  describe "new" do
    test "will spawn a new socket at a url", %{window: window} do
      run_server(Server, fn port ->
        {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

        request =
          %Protos.Browser.Window.Socket {
            url: "localhost:4567/websocket",
            window_name: Atom.to_string(window.name)
          }

        {:ok, response} = Client.new(channel, request)
        pid = Process.whereis(String.to_existing_atom(response.name))
        assert Process.alive?(pid)
      end)
    end
  end

  describe "send" do
    test "will send a message over the socket", %{window: window} do
      run_server(Server, fn port ->
        {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")
        {:ok, socket, _window} = Window.new_socket(window, url: "http://localhost:4567/websocket")

        pid = self()

        receiver = fn(msg) ->
          send(pid, msg)
        end

        :ok = WebSocket.attach_receiver(socket, receiver)

        request =
          %Protos.Browser.Window.Socket.Message {
            type: "text",
            data: "ping",
            socket_name: Atom.to_string(socket.name)
          }

        Client.send(channel, request)

        assert_receive [{:text, "pong"}]
      end)
    end
  end

  describe "receive" do
    test "will stream socket inbound messages", %{window: window} do
      run_server(Server, fn port ->
        {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")
        {:ok, socket, _window} = Window.new_socket(window, url: "http://localhost:4567/websocket")
        pid = self()

        Task.async(fn ->
          {:ok, stream} = Client.receive(channel, WebSocket.to_protoc(socket))

          [{:ok, message}] = Stream.take(stream, 1) |> Enum.to_list()
          send(pid, {:message, message})
        end)

        Task.async(fn ->
          :timer.sleep(50)
          :ok = WebSocket.send(socket, {:text, "ping"})
        end)

        message = receive do
          {:message, message} -> message

        after
          500 -> assert false, "No messages received"
        end

        assert message.type == "text"
        assert message.data == "pong"

        send(:"#{socket.name}-receive", :stop)
      end)
    end
  end
end
