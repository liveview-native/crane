defmodule Crane.WindowTest do
  use ExUnit.Case
  alias Plug.Conn

  alias Crane.Window

  describe "new" do
    test "will spawn a new Window process" do
      {:ok, %Window{pid: pid}} = Window.new()

      refute is_nil(pid)
    end
  end

  describe "close" do
    test "will close a Window process" do
      {:ok, window} = Window.new()

      :ok = Window.close(window)

      refute Process.alive?(window.pid)
    end
  end

  describe "fetch" do
    setup do
      {:ok, pid} = Window.start_link(nil)

      window = GenServer.call(pid, :get)

      {:ok, window: window}
    end

    test "with url", %{window: window} do
      Req.Test.stub(Crane.Window, fn(conn) ->
        Plug.Conn.send_resp(conn, conn.status || 200, "<Text>Success!</Text>")
      end)

      Req.Test.allow(Crane.Window, self(), window.pid)

      {:ok, window} = Window.fetch(window, url: "https://dockyard.com")

      assert window.response.body == "<Text>Success!</Text>"
      assert window.history.index == 1
      assert window.history.stack == [
        {%{}, headers: [], method: "GET", url: "https://dockyard.com"}
      ]
    end

    test "updates cookie jar when cookies are sent back", %{window: window} do
      url = "https://dockyard.com"
      
      Req.Test.stub(Crane.Window, fn(conn) ->
        conn
        |> Conn.put_resp_cookie("session-id", "123456")
        |> Conn.send_resp(200, "<Text>Success!</Text>")
      end)

      Req.Test.allow(Crane.Window, self(), window.pid)
      {:ok, window} = Window.fetch(window, url: url)
      {:ok, cookie, _cookie_jar} = HttpCookie.Jar.get_cookie_header_value(window.cookie_jar, URI.new!(url))

      assert cookie == "session-id=123456"
    end
  end

  # describe "sockets" do
  #   test "create a new socket", %{window: window} do
  #     {:ok, socket, window} = Window.create_socket(window, url: "https://dockyard.com")
  #   end
  # end
end
