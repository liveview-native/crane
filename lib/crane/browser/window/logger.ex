defmodule Crane.Browser.Window.Logger do
  import Crane.Utils
  alias Crane.Browser.Window

  require Logger

  use Crane.Object,
    owner: Window,
    messages: []

  @impl true
  def handle_cast({:new_message, message}, %__MODULE__{messages: messages} = logger) do
    broadcast(logger, {:new_message, message})
    {:noreply, %__MODULE__{logger | messages: List.insert_at(messages, -1, message)}}
  end

  for level <- Logger.levels() do
    def unquote(level)(%__MODULE__{name: name}, message) do
      GenServer.cast(name, {:new_message, %{type: "Logs", level: unquote(level), message: message}})
    end
  end

  def network(%__MODULE__{name: name}, details) do
    GenServer.cast(name, {:new_message, %{type: "Network", details: details}})
  end
end
