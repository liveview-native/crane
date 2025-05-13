defmodule Crane do
  alias Crane.{
    Browser,
    Browser.Window
  }

  use Crane.Object,
    name: __MODULE__

  defchild browser: Browser

  def handle_call({:launch, opts}, _from, crane) do
    {name, opts} = Keyword.pop(opts, :name)

    with pid when not is_nil(pid) <- Process.whereis(name),
      true <- Process.alive?(pid),
      {:ok, window} <- Crane.Browser.Window.get(name),
      {:ok, window} <- Crane.Browser.Window.reset_view_trees(window),
      {:ok, browser} <- Crane.Browser.get(window.browser_name) do
        {:reply, {:ok, Window.strip!(window), Browser.strip!(browser)}, crane}
    else
      _error ->
        with {:ok, browser, crane} <- new_browser(crane),
          {:ok, window, browser} <- Crane.Browser.new_window(browser, name: name, scripts: [
            LiveView
          ]),
          {:ok, window} <- Crane.Browser.Window.visit(window, opts) do
            {:reply, {:ok, Window.strip!(window), Browser.strip!(browser)}, crane}
        else
          error ->
            {:reply, {:error, "failed to launch"}, crane}
        end
  
    end
  end

  def handle_call(:start, _from, crane) do
    {:stop, "restarting", crane}
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
    GenServer.call(Crane, {:launch, options})
  end
end
