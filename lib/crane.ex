defmodule Crane do
  use GenServer
  import Crane.Utils

  alias Crane.Browser

  defstruct refs: %{} 

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    Process.flag(:trap_exit, true)
    {:ok, %__MODULE__{}}
  end

  def handle_call(:get, _from, crane) do
    {:reply, {:ok, crane}, crane}
  end

  def handle_call(:browsers, _from, %__MODULE__{refs: refs} = crane) do
    browsers = get_reference_resource(refs, :browser, fn(name) ->
      Browser.get(name)
    end)
    |> Enum.sort_by(&(&1.created_at), {:asc, DateTime})

    {:reply, {:ok, browsers}, crane}
  end

  def handle_call(:new_browser, _from, %__MODULE__{refs: refs} = crane) do
    with {:ok, browser} <- Browser.new(),
      refs <- monitor(browser, refs) do
        crane = %__MODULE__{crane | refs: refs}
        broadcast(Crane, {:new_browser, browser})

        {:reply, {:ok, browser, crane}, crane}
    else
      error -> {:reply, error, crane}
    end
  end

  def handle_call(_msg, _from, browser) do
    {:noreply, browser}
  end

  def handle_cast(_msg, browser) do
    {:noreply, browser}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %__MODULE__{refs: refs} = crane) do
    {_name, refs} = Map.pop(refs, ref)

    {:noreply, %__MODULE__{crane | refs: refs}}
  end

  def handle_info(:reconnect, crane) do
    IO.puts("RECONNECT")
    {:noreply, crane}
  end

  def handle_info(_msg, browser) do
    {:noreply, browser}
  end

  def new_browser do
    GenServer.call(__MODULE__, :new_browser)
  end

  def new_browser! do
    {:ok, browser} = new_browser()
    browser
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def get! do
    {:ok, crane} = get()
    crane
  end

  def browsers do
    GenServer.call(__MODULE__, :browsers)
  end

  def browsers! do
    {:ok, browsers} = browsers()
    browsers 
  end

  def close_browser(%Browser{} = browser) do
    :ok = Browser.close(browser)
    get()
  end

  def launch(options) do
    with {:ok, browser, _crane} <- new_browser(),
      {:ok, window, browser} <- Crane.Browser.new_window(browser),
      {:ok, _response, window} <- Crane.Browser.Window.visit(window, options) do
        {:ok, window, browser}
    end
  end
end
