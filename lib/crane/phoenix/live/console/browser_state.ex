defmodule Crane.Phoenix.Live.Console.BrowserState do
  alias Crane.Phoenix.Live.Console.WindowState
  alias Crane.Browser

  @behaviour Access

  defstruct active_window: nil,
    window_states: %{}

  def build(browsers) do
    Enum.reduce(browsers, %{}, fn(browser, states) ->
      {:ok, windows} = Browser.windows(browser)

      Map.put(states, browser.name, %__MODULE__{
        active_window: Enum.at(windows, 0),
        window_states: WindowState.build(windows)
      })
    end)
  end

  def fetch(%__MODULE__{} = browser_state, key) do
    Map.fetch(browser_state, key)
  end

  def get_and_update(%__MODULE__{} = browser_state, key, fun) do
    Map.get_and_update(browser_state, key, fun)
  end

  def pop(%__MODULE__{} = browser_state, key) do
    Map.pop(browser_state, key)
  end
end
