defmodule Crane.Browser.WindowTest do
  use ExUnit.Case
  alias Plug.Conn

  alias Crane.Browser.Window
  alias Crane.Browser

  import Crane.Test.Utils

  describe "new" do
    test "will spawn a new Window process" do
      {:ok, %Window{name: name}} = Window.new()

      refute is_nil(Process.whereis(name))
    end
  end

  describe "close" do
    test "will close a Window process" do
      {:ok, window} = Window.new()

      :ok = Window.close(window)

      refute Process.whereis(window.name)
    end
  end

  describe "visit" do
    setup do
      {:ok, pid} = Window.start_link(%{})

      {:ok, window} = GenServer.call(pid, :get)

      {:ok, window: window}
    end

    test "with url", %{window: window} do
      Req.Test.stub(Window, fn(conn) ->
        Plug.Conn.send_resp(conn, conn.status || 200, "<Text>Success!</Text>")
      end)

      Req.Test.allow(Window, self(), pid_for(window))

      {:ok, response, window} = Window.visit(window, url: "https://dockyard.com")

      assert response.body == "<Text>Success!</Text>"
      assert window.response.body == "<Text>Success!</Text>"
      assert window.history.index == 1
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
      {:ok, browser} = Browser.get()
      {:ok, cookie, _cookie_jar} = HttpCookie.Jar.get_cookie_header_value(browser.cookie_jar, URI.new!(url))

      assert cookie == "session-id=123456"
    end
  end

  describe "fetch" do
    setup do
      {:ok, pid} = Window.start_link(%{})
      {:ok, window} = GenServer.call(pid, :get)
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
      assert window.history.index == 0
      assert window.history.stack == []
    end

    test "updates browser cookie jar when cookies are sent back", %{window: window} do
      url = "https://dockyard.com"
      
      Req.Test.stub(Window, fn(conn) ->
        conn
        |> Conn.put_resp_cookie("session-id", "123456")
        |> Conn.send_resp(200, "<Text>Success!</Text>")
      end)

      Req.Test.allow(Window, self(), pid_for(window))

      {:ok, _response, _window} = Window.fetch(window, url: url)
      {:ok, browser} = Browser.get()
      {:ok, cookie, _cookie_jar} = HttpCookie.Jar.get_cookie_header_value(browser.cookie_jar, URI.new!(url))

      assert cookie == "session-id=123456"
    end
  end

  describe "restore" do
    test "will restore a previously closed window state" do
      {:ok, window} = Window.new()
      
      Req.Test.stub(Window, fn(conn) ->
        Plug.Conn.send_resp(conn, conn.status || 200, "<Text>Success!</Text>")
      end)

      Req.Test.allow(Window, self(), pid_for(window))

      {:ok, _response, window} = Window.visit(window, url: "https://dockyard.com")
      old_pid = Process.whereis(window.name)

      :ok = Window.close(window)

      {:ok, restored_window} = Window.new(window)

      assert window.name == restored_window.name
      assert window.history == restored_window.history
      assert window.response == restored_window.response
      assert window.view_tree == restored_window.view_tree

      refute old_pid == Process.whereis(restored_window.name)
    end
  end

  # describe "sockets" do
  #   test "create a new socket", %{window: window} do
  #     {:ok, socket, window} = Window.create_socket(window, url: "https://dockyard.com")
  #   end
  # end
end
