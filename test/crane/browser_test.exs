defmodule Crane.BrowserTest do
  use ExUnit.Case
  import Crane.Test.Utils

  alias Crane.{Browser, Browser.Window}

  setup config do
    Application.put_env(:crane, :pubsub, config.test)
    start_pubsub(config)

    on_exit fn ->
      Application.delete_env(:crane, :pubsub)
    end

    :ok
  end

  describe "new" do
    test "will create a new browser" do
      {:ok, %Browser{name: name} = _browser} = Browser.new()

      refute is_nil(Process.whereis(name))
    end

    test "will return browser struct with headers assigned" do
      headers = [
        {"Foo", "Bar"}
      ]
      {:ok, %Browser{} = browser} = Browser.new(headers: headers)

      Enum.each(headers, fn(header) ->
        assert Enum.member?(browser.headers, header)
      end)
    end
  end

  describe "get" do
    setup do
      {:ok, browser_pid} = Browser.start_link([])
      {:ok, browser} = GenServer.call(browser_pid, :get)

      on_exit fn ->
        Process.exit(browser_pid, :normal)
      end

      {:ok, browser: browser}
    end

    test "will return the browser struct", %{browser: browser} do
      {:ok, %Browser{} = got_browser} = Browser.get(%Browser{name: browser.name})

      assert browser == got_browser
    end

    test "bang value will return without ok", %{browser: browser} do
      got_browser = Browser.get!(%Browser{name: browser.name})

      assert browser == got_browser
    end
  end

  describe "windows" do
    setup do
      {:ok, browser_pid} = Browser.start_link([])
      {:ok, browser} = GenServer.call(browser_pid, :get)

      on_exit fn ->
        Process.exit(browser_pid, :normal)
      end

      {:ok, browser: browser}
    end

    test "will return all windows in a tuple", %{browser: browser} do
      {:ok, %Window{} = window_1, browser} = Browser.new_window(browser)
      {:ok, %Window{} = window_2, browser} = Browser.new_window(browser)

      {:ok, windows} = Browser.windows(browser)

      assert window_1 in windows
      assert window_2 in windows
    end

    test "will return all windows", %{browser: browser} do
      {:ok, %Window{} = window_1, browser} = Browser.new_window(browser)
      {:ok, %Window{} = window_2, browser} = Browser.new_window(browser)

      windows = Browser.windows!(browser)

      assert window_1 in windows
      assert window_2 in windows
    end

    test "will spawn a new window for the browser that is monitored by the browser", %{browser: browser} do
      {:ok, %Window{} = window, browser} = Browser.new_window(browser)

      assert window.name in Map.values(browser.refs)
      assert window.history.index == -1

      pid = Process.whereis(window.name)
      Process.exit(pid, :kill)

      :timer.sleep(10)

      {:ok, browser} = Browser.get(browser)

      refute window.name in Map.values(browser.refs)
    end
  end

  describe "close" do
    test "will close a Browser process" do
      {:ok, browser} = Browser.new()

      pid = Process.whereis(browser.name)

      assert Process.alive?(pid)

      :ok = Browser.close(browser)

      refute Process.alive?(pid)
    end

    test "when browser closes all windows are closed too" do
      {:ok, browser} = Browser.new()

      {:ok, %Window{} = window_1, browser} = Browser.new_window(browser)
      {:ok, %Window{} = window_2, browser} = Browser.new_window(browser)

      window_1_pid = Process.whereis(window_1.name)
      window_2_pid = Process.whereis(window_2.name)

      :ok = Browser.close(browser)

      :timer.sleep(10)

      refute Process.alive?(window_1_pid)
      refute Process.alive?(window_2_pid)
    end
  end

  describe "close window" do
    test "will close all windows and return updated browser" do
      {:ok, browser} = Browser.new()

      {:ok, %Window{} = window_1, browser} = Browser.new_window(browser)
      {:ok, %Window{} = window_2, browser} = Browser.new_window(browser)

      window_1_pid = Process.whereis(window_1.name)
      window_2_pid = Process.whereis(window_2.name)

      assert window_1.name in Map.values(browser.refs)

      {:ok, browser} = Browser.close_window(browser, window_1)

      :timer.sleep(10)

      refute Process.alive?(window_1_pid)
      assert Process.alive?(window_2_pid)

      refute window_1.name in Map.values(browser.refs)
      assert window_2.name in Map.values(browser.refs)
    end
  end

  describe "restore_window" do
    test "will restore a previously closed window state" do
      {:ok, browser} = Browser.new()
      {:ok, window, browser} = Browser.new_window(browser)
      
      Req.Test.stub(Window, fn(conn) ->
        Plug.Conn.send_resp(conn, conn.status || 200, "<Text>Success!</Text>")
      end)

      Req.Test.allow(Window, self(), pid_for(window))

      {:ok, window} = Window.visit(window, url: "https://dockyard.com")
      old_pid = Process.whereis(window.name)

      :ok = Window.close(window)

      {:ok, restored_window, browser} = Browser.restore_window(browser, window)

      assert window.name == restored_window.name
      assert window.history == restored_window.history
      assert window.response == restored_window.response
      # assert window.view_trees == restored_window.view_trees
      assert restored_window.browser_name == browser.name

      refute old_pid == Process.whereis(restored_window.name)

      assert restored_window.name in Map.values(browser.refs)

      pid = Process.whereis(window.name)
      Process.exit(pid, :kill)

      :timer.sleep(10)

      {:ok, browser} = Browser.get(browser)

      refute restored_window.name in Map.values(browser.refs)
    end
  end
end
