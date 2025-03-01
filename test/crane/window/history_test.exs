defmodule Crane.HistoryTest do
  use ExUnit.Case

  alias Crane.Window.History

  setup do
    history = %History{index: 2, stack: [
      {%{}, url: "/"},
      {%{}, url: "/1"},
      {%{}, url: "/2"},
      {%{}, url: "/3"},
    ]}

    {:ok, [history: history]}
  end

  describe "go" do
    test "()", context do
      {:ok, frame, history} = History.go(context.history)

      assert frame == {%{}, url: "/2"}
      assert history.index == 2
    end

    test "(0)", context do
      {:ok, frame, history} = History.go(context.history, 0)

      assert frame == {%{}, url: "/2"}
      assert history.index == 2
    end

    test "(1) when there is a frame to navigate to in the stack", context do
      {:ok, frame, history} = History.go(context.history, 1)

      assert frame == {%{}, url: "/3"}
      assert history.index == 3
    end

    test "(-1) when there is a frame to navigate to in the stack", context do
      {:ok, frame, history} = History.go(context.history, -1)

      assert frame == {%{}, url: "/1"}
      assert history.index == 1
    end

    test "(4) when there is a frame to navigate to in the stack", context do
      {:error, _message} = History.go(context.history, 4)
    end
  end

  describe "push_state" do
    test "when no :url is included in the options", context do
      {:error, _message} = History.push_state(context.history, %{}, [])
    end

    test "when valid options are passed will add new frame to the end of stack and update index", context do
      {:ok, frame, history} = History.push_state(%{context.history | index: 3}, %{}, url: "/4")

      assert frame == {%{}, url: "/4"}
      assert history.index == 4
    end

    test "when valid options are passed and index is mid-stack will drop remaining stack frames", context do
      {:ok, frame, history} = History.push_state(%{context.history | index: 0}, %{}, url: "/4")

      assert frame == {%{}, url: "/4"}
      assert history.index == 1
      assert history.stack == [
        {%{}, url: "/"},
        {%{}, url: "/4"}
      ]
    end
  end

  describe "replace_state" do
    test "when no :url is included in the options", context do
      {:error, _message} = History.replace_state(context.history, %{}, [])
    end

    test "when valid options are passed will replace the current frame with the new frame", context do
      {:ok, frame, history} = History.replace_state(context.history, %{}, url: "/4")

      assert frame == {%{}, url: "/4"}
      assert history.index == 2
      assert history.stack == [
        {%{}, url: "/"},
        {%{}, url: "/1"},
        {%{}, url: "/4"},
        {%{}, url: "/3"}
      ]
    end
  end
end
