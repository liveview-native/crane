defmodule Crane.Browser.Window.Console do
  use GenServer

  import Crane.Utils

  defstruct logs: %{},
    name: nil,
    view_tree: nil,
    window_name: nil

  def start_link(console) do
    name = generate_name(:console)

    GenServer.start_link(__MODULE__, %__MODULE__{console | name: name}, name: name)
  end

  def init(console) do
    {:ok, console}
  end

  def handle_cast({:log, type, message}, %__MODULE__{logs: logs} = console) do
    logs = Map.update(logs, type, [], fn(entries) ->
      List.insert_at(entries, -1, message)
    end)

    Phoenix.PubSub.broadcast(PhoenixPlayground.PubSub, "logger", {:foobar, "123"})

    {:noreply, %__MODULE__{console | logs: logs}}
  end
end
