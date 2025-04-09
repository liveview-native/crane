defmodule CraneTest do
  use ExUnit.Case
  import Crane.Test.Utils

  alias Crane.Browser

  setup config do
    Application.put_env(:crane, :pubsub, config.test)
    start_pubsub(config)

    on_exit fn ->
      Application.delete_env(:crane, :pubsub)
    end

    :ok
  end

  describe "get" do
    test "will get the Crane state" do
      {:ok, %Crane{} = _crane} = Crane.get()

      pid = Process.whereis(Crane)
      assert Process.alive?(pid)
    end
  end

  describe "close_browser" do
    test "will close all browsers and return updated crane" do
      {:ok, %Browser{} = browser_1, _crane} = Crane.new_browser()
      {:ok, %Browser{} = browser_2, crane} = Crane.new_browser()

      browser_1_pid = Process.whereis(browser_1.name)
      browser_2_pid = Process.whereis(browser_2.name)

      assert Atom.to_string(browser_1.name) in Map.values(crane.refs)

      {:ok, crane} = Crane.close_browser(browser_1)

      :timer.sleep(10)

      refute Process.alive?(browser_1_pid)
      assert Process.alive?(browser_2_pid)

      refute Atom.to_string(browser_1.name) in Map.values(crane.refs)
      assert Atom.to_string(browser_2.name) in Map.values(crane.refs)
    end
  end
end
