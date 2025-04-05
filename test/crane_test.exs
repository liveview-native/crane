defmodule CraneTest do
  use ExUnit.Case

  describe "get" do
    test "will get the Crane state" do
      {:ok, %Crane{} = _crane} = Crane.get()

      pid = Process.whereis(Crane)
      assert Process.alive?(pid)
    end
  end
end
