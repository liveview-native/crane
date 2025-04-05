defmodule Crane do
  use GenServer

  import Crane.Utils

  alias Crane.Browser

  defstruct refs: %{} 

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, %__MODULE__{}}
  end

  def handle_call(:get, _from, crane) do
    {:reply, {:ok, crane}, crane}
  end

  def handle_call(:browsers, _from, %__MODULE__{refs: refs} = crane) do
    browsers = Enum.reduce(refs, [], fn
      {_ref, "browser-" <> _id = name}, acc ->
        {:ok, browser} = Crane.Browser.get(name)
        [browser | acc]
      _other, acc -> acc
    end)

    {:reply, {:ok, browsers}, crane}
  end

  def handle_call(:new_browser, _from, %__MODULE__{refs: refs} = crane) do
    with {:ok, browser} <- Browser.new(),
      refs <- monitor(browser, refs) do

      crane = %__MODULE__{crane | refs: refs}

      Phoenix.PubSub.broadcast(PhoenixPlayground.PubSub, Atom.to_string(__MODULE__), :update)
      {:reply, {:ok, browser, crane}, crane}
    else
      error -> {:reply, error, crane}
    end
  end

  def handle_info(:reconnect, crane) do
    {:noreply, crane}
  end

  def new_browser do
    GenServer.call(__MODULE__, :new_browser)
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end
end
