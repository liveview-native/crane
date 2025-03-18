defmodule Crane.Browser.Window.WebSocketTest do
  use ExUnit.Case
  # alias Plug.Conn

  alias Crane.{
    # Browser,
    Browser.Window,
    Browser.Window.WebSocket
  }

  # import Crane.Test.Utils

  describe "new" do
    test "will connect to an existing websocket server" do
      {:ok, socket} = WebSocket.new(%Window{}, url: "http://localhost:4567/websocket")

      WebSocket.send(socket, {:text, "ping"})
    end
  end
end
