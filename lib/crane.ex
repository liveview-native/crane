defmodule Crane do
  alias Crane.Browser

  use Crane.Object,
    name: __MODULE__

  defchild browser: Browser

  def handle_call({:launch, options}, _from, crane) do
    with {:ok, browser, crane} <- new_browser(crane),
      {:ok, window, browser} <- Crane.Browser.new_window(browser, scripts: [
        LiveView
      ]),
      {:ok, window} <- Crane.Browser.Window.visit(window, options) do
        {:reply, {:ok, window, browser}, crane}
    end
  end

  def handle_cast({:run_script, script, window, opts}, crane) do
    apply(script, :call, [window, opts])
    {:noreply, crane}
  end

  def new_browser(%__MODULE__{refs: refs} = crane) do
    with {:ok, browser} <- Browser.new([]),
      refs <- Crane.Utils.monitor(browser, refs) do
        crane = %__MODULE__{crane | refs: refs}
        Crane.Utils.broadcast(Crane, {:new_browser, browser})

        {:ok, browser, crane}
    else
      error -> {:error, crane}
    end
  end

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
