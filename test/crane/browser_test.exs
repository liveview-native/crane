defmodule Crane.BrowserTest do
  use ExUnit.Case

  alias Crane.{Browser, Browser.Window}

  import Crane.Test.Utils

  describe "get" do
    test "will return the browser struct" do
      {:ok, %Browser{} = _browser} = Browser.get()
    end

    test "will return browser struct with headers assigned" do
      headers = [
        {"Foo", "Bar"}
      ]
      {:ok, %Browser{} = browser} = Browser.get(%Browser{headers: headers})

      Enum.each(headers, fn(header) ->
        assert Enum.member?(browser.headers, header)
      end)
    end
  end

  describe "new_window" do
    test "will spawn a new window for the browsesr that is monitored by the browser" do
      {:ok, %Window{} = window} = Browser.new_window()

      {:ok, %Browser{} = browser} = Browser.get()

      assert browser.windows[window.name] == window
      assert window.history.index == -1
    end

    test "with initial state will create new window with that state" do
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
end
