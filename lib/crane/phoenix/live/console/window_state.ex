defmodule Crane.Phoenix.Live.Console.WindowState do
  defstruct active_tab: "Logs",
    tab_state: %{},
    view_tree: []

  @behaviour Access

  def build(windows) do
    Enum.reduce(windows, %{}, fn(window, states) ->
      Map.put(states, window.name, %__MODULE__{})
    end)
  end

  def fetch(%__MODULE__{} = window_state, key) do
    Map.fetch(window_state, key)
  end

  def get_and_update(%__MODULE__{} = window_state, key, fun) do
    Map.get_and_update(window_state, key, fun)
  end

  def pop(%__MODULE__{} = window_state, key) do
    Map.pop(window_state, key)
  end
end
