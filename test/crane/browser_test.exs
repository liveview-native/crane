defmodule Crane.BrowserTest do
  use ExUnit.Case

  alias Crane.{Browser, Browser.Window}

  setup do
    {:ok, browser_pid} = Browser.start_link([])

    on_exit fn ->
      Process.exit(browser_pid, :normal)
    end

    :ok
  end

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

  describe "windows" do
    test "will return all window names" do
      {:ok, %Window{} = window_1, browser} = Browser.new_window(%Browser{})
      {:ok, %Window{} = window_2, browser} = Browser.new_window(browser)

      {:ok, windows} = Browser.windows(browser)

      assert window_1 in windows
      assert window_2 in windows
    end

    test "will spawn a new window for the browser that is monitored by the browser" do
      {:ok, %Window{} = window, browser} = Browser.new_window(%Browser{})

      window_name = Atom.to_string(window.name)

      assert window_name in Map.values(browser.refs)
      assert window.history.index == -1

      pid = Process.whereis(window.name)
      Process.exit(pid, :kill)

      :timer.sleep(10)

      {:ok, browser} = Browser.get()

      refute window_name in Map.values(browser.refs)
    end
  end
end
