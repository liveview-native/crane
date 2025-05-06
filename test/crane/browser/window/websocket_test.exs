defmodule Crane.Browser.Window.WebSocketTest do
  use ExUnit.Case
  # alias Plug.Conn

  alias Crane.Browser.Window.WebSocket

  describe "new" do
    test "will connect to an existing websocket server" do
      {:ok, socket} = WebSocket.new(url: "http://localhost:4567/websocket")

      pid = self()

      :ok = WebSocket.attach_receiver(socket, pid)
      WebSocket.send(socket, {:text, "ping"})

      assert_receive [{:text, "pong"}]
    end
  end

  describe "close" do
    test "will close socket" do
      {:ok, %WebSocket{name: name} = socket} = WebSocket.new(url: "http://localhost:4567/websocket")

      pid = Process.whereis(name)
      assert Process.alive?(pid)

      WebSocket.close(socket)

      :timer.sleep(100)

      refute Process.alive?(pid)
    end
  end
end
