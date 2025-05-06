defmodule Crane do
  alias Crane.Browser

  use Crane.Object,
    name: __MODULE__

  defchild browser: Browser

  def handle_call(_msg, _from, browser) do
    {:noreply, browser}
  end

  def handle_cast(_msg, browser) do
    {:noreply, browser}
  end

  def handle_info(:reconnect, crane) do
    IO.puts("RECONNECT")
    {:noreply, crane}
  end

  def handle_info(_msg, browser) do
    {:noreply, browser}
  end

  def reconnect do
    GenServer.cast(__MODULE__, :reconnect)
  end

  def launch(options) do
    with {:ok, browser, _crane} <- new_browser(),
      {:ok, window, browser} <- Crane.Browser.new_window(browser),
      {:ok, window} <- Crane.Browser.Window.visit(window, options) do
        {:ok, window, browser}
    end
  end
end
