defmodule Crane.Browser.WindowTest do
  use ExUnit.Case
  alias Plug.Conn

  alias Crane.{
    Browser,
    Browser.Window,
    Browser.Window.WebSocket
  }

  import Crane.Test.Utils

  setup config do
    Application.put_env(:crane, :pubsub, config.test)
    start_pubsub(config)
    {:ok, browser} = Browser.new()

    on_exit fn ->
      Application.delete_env(:crane, :pubsub)
    end

    {:ok, browser: browser}
  end

  describe "new" do
    test "will spawn a new Window process", %{browser: browser} do
      {:ok, %Window{name: name}} = Window.new(browser: browser)

      refute is_nil(Process.whereis(name))
    end
  end

  describe "get" do
    setup do
      {:ok, browser} = Browser.new()
      {:ok, window_pid} = Window.start_link(browser: browser)
      {:ok, window} = GenServer.call(window_pid, :get)

      {:ok, window: window}
    end

    test "will return the window struct", %{window: window} do
      {:ok, %Window{} = got_window} = Window.get(%Window{name: window.name})
      assert window == got_window
    end

    test "bang value will return without ok", %{window: window} do
      got_window = Window.get!(%Window{name: window.name})
      assert window == got_window
    end
  end

  describe "close" do
    test "will close a Window process", %{browser: browser} do
      {:ok, window} = Window.new(browser: browser)

      pid = Process.whereis(window.name)

      assert Process.alive?(pid)

      :ok = Window.close(window)

      refute Process.alive?(pid)
    end

    test "when window closes all sockets are closed too", %{browser: browser} do
      {:ok, window} = Window.new(browser: browser)

      {:ok, %WebSocket{} = socket_1, window} = Window.new_socket(window, url: "http://localhost:4567/websocket")
      {:ok, %WebSocket{} = socket_2, window} = Window.new_socket(window, url: "http://localhost:4567/websocket")

      socket_1_pid = Process.whereis(socket_1.name)
      socket_2_pid = Process.whereis(socket_2.name)

      :ok = Window.close(window)

      :timer.sleep(10)

      refute Process.alive?(socket_1_pid)
      refute Process.alive?(socket_2_pid)
    end
  end

  describe "visit" do
    setup %{browser: browser} do
      {:ok, pid} = Window.start_link(%{browser_name: browser.name})

      {:ok, window} = GenServer.call(pid, :get)

      {:ok, window: window}
    end

    test "with url", %{window: window} do
      Req.Test.stub(Window, fn(conn) ->
        Plug.Conn.send_resp(conn, conn.status || 200, "<Text>Success!</Text>")
      end)

      Req.Test.allow(Window, self(), pid_for(window))

      {:ok, response, window} = Window.visit(window, url: "https://dockyard.com")

      assert response == window.response
      assert response.body == "<Text>Success!</Text>"
      assert window.history.index == 0
      assert window.history.stack == [
        {%{}, headers: [], method: "GET", url: "https://dockyard.com"}
      ]
    end

    test "updates cookie jar when cookies are sent back", %{window: window} do
      url = "https://dockyard.com"
      
      Req.Test.stub(Window, fn(conn) ->
        conn
        |> Conn.put_resp_cookie("session-id", "123456")
        |> Conn.send_resp(200, "<Text>Success!</Text>")
      end)

      Req.Test.allow(Window, self(), pid_for(window))
      {:ok, _response, _window} = Window.visit(window, url: url)
      {:ok, browser} = Browser.get(window.browser_name)
      {:ok, cookie, _cookie_jar} = HttpCookie.Jar.get_cookie_header_value(browser.cookie_jar, URI.new!(url))

      assert cookie == "session-id=123456"
    end
  end

  describe "fetch" do
    setup %{browser: browser} do
      {:ok, window} = Window.new(browser: browser)

      {:ok, window: window}
    end

    test "with url", %{window: window} do
      Req.Test.stub(Window, fn(conn) ->
        Plug.Conn.send_resp(conn, conn.status || 200, "<Text>Success!</Text>")
      end)

      Req.Test.allow(Window, self(), pid_for(window))

      {:ok, response, window} = Window.fetch(window, url: "https://dockyard.com")

      assert window.response == nil
      assert response.body == "<Text>Success!</Text>"
      assert window.history.index == -1
      assert window.history.stack == []
    end

    test "updates browser cookie jar when cookies are sent back", %{browser: browser, window: window} do
      url = "https://dockyard.com"
      
      Req.Test.stub(Window, fn(conn) ->
        conn
        |> Conn.put_resp_cookie("session-id", "123456")
        |> Conn.send_resp(200, "<Text>Success!</Text>")
      end)

      Req.Test.allow(Window, self(), pid_for(window))

      {:ok, _response, _window} = Window.fetch(window, url: url)
      {:ok, browser} = Browser.get(browser.name)
      {:ok, cookie, _cookie_jar} = HttpCookie.Jar.get_cookie_header_value(browser.cookie_jar, URI.new!(url))

      assert cookie == "session-id=123456"
    end
  end

  describe "forward/back/go" do
    setup %{browser: browser} do
      {:ok, window} = Window.new(browser: browser)
      
      Req.Test.stub(Window, fn(conn) ->
        case Conn.request_url(conn) do
          "https://dockyard.com/1" -> 
            Conn.send_resp(conn, 200, "<Text>1</Text>")
          "https://dockyard.com/2" -> 
            Conn.send_resp(conn, 200, "<Text>2</Text>")
          "https://dockyard.com/3" -> 
            Conn.send_resp(conn, 200, "<Text>3</Text>")
          "https://dockyard.com/4" -> 
            Conn.send_resp(conn, 200, "<Text>4</Text>")
          "https://dockyard.com/5" -> 
            Conn.send_resp(conn, 200, "<Text>5</Text>")
        end
      end)

      Req.Test.allow(Window, self(), pid_for(window))

      {:ok, _response, window} = Window.visit(window, url: "https://dockyard.com/1")
      {:ok, _response, window} = Window.visit(window, url: "https://dockyard.com/2")
      {:ok, _response, window} = Window.visit(window, url: "https://dockyard.com/3")
      {:ok, _response, window} = Window.visit(window, url: "https://dockyard.com/4")
      {:ok, _response, window} = Window.visit(window, url: "https://dockyard.com/5")

      {:ok, window: window}
    end

    test "will navigate history", %{window: window} do
      {:ok, _response, window} = Window.back(window)
      assert window.response.body == "<Text>4</Text>"
      {:ok, _response, window} = Window.back(window)
      assert window.response.body == "<Text>3</Text>"

      {:ok, _response, window} = Window.go(window, 2)
      assert window.response.body == "<Text>5</Text>"
      {:ok, _response, window} = Window.go(window, -4)
      assert window.response.body == "<Text>1</Text>"

      {:ok, _response, window} = Window.forward(window)
      assert window.response.body == "<Text>2</Text>"
      {:ok, _response, window} = Window.forward(window)
      assert window.response.body == "<Text>3</Text>"
    end
  end

  describe "restore" do
    test "will restore a previously closed window state", %{browser: browser} do
      {:ok, window} = Window.new(browser: browser)
      
      Req.Test.stub(Window, fn(conn) ->
        Plug.Conn.send_resp(conn, conn.status || 200, "<Text>Success!</Text>")
      end)

      Req.Test.allow(Window, self(), pid_for(window))

      {:ok, _response, window} = Window.visit(window, url: "https://dockyard.com")
      old_pid = Process.whereis(window.name)

      :ok = Window.close(window)

      {:ok, restored_window} = Window.restore(window)

      assert window.name == restored_window.name
      assert window.history == restored_window.history
      assert window.response == restored_window.response
      # assert window.view_trees == restored_window.view_trees

      refute old_pid == Process.whereis(restored_window.name)
    end
  end

  describe "sockets" do
    setup do
      {:ok, pid} = Window.start_link(%{})
      {:ok, window} = GenServer.call(pid, :get)
      {:ok, window: window}
    end

    test "will return all sockets in a tuple", %{window: window} do
      {:ok, %WebSocket{} = socket_1, window} = Window.new_socket(window, url: "http://localhost:4567/websocket")
      {:ok, %WebSocket{} = socket_2, window} = Window.new_socket(window, url: "http://localhost:4567/websocket")

      {:ok, sockets} = Window.sockets(window) 

      assert socket_1 in sockets
      assert socket_2 in sockets
    end

    test "will return all sockets", %{window: window} do
      {:ok, %WebSocket{} = socket_1, window} = Window.new_socket(window, url: "http://localhost:4567/websocket")
      {:ok, %WebSocket{} = socket_2, window} = Window.new_socket(window, url: "http://localhost:4567/websocket")

      sockets = Window.sockets!(window) 

      assert socket_1 in sockets
      assert socket_2 in sockets
    end

    test "will spawn a new socket for the window that is monitored by the window", %{window: window} do
      {:ok, %WebSocket{} = socket, window} = Window.new_socket(window, url: "http://localhost:4567/websocket")
      {:ok, window} = Window.get(window)

      assert socket.name in Map.values(window.refs)

      pid = Process.whereis(socket.name)
      Process.exit(pid, :kill)

      :timer.sleep(10)

      {:ok, window} = Window.get(window)

      refute socket.name in Map.values(window.refs)
    end
  end
end
