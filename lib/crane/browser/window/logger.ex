defmodule Crane.Browser.Window.Logger do
  use GenServer

  import Crane.Utils

  require Logger

  defstruct name: nil,
    window_name: nil,
    messages: []

  def start_link(args) when is_list(args) do
    name = generate_name(:logger)
    GenServer.start_link(__MODULE__, [{:name, name} | args], name: name)
  end

  @impl true
  def init(args) when is_list(args) do
    {:ok, %__MODULE__{
      name: args[:name],
      window_name: args[:window].name
    }}
  end

  @impl true
  def handle_call(:get, _from, logger) do
    {:reply, {:ok, logger}, logger}
  end

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

  def get(%__MODULE__{name: name}),
    do: get(name)

  def get(name) when is_binary(name),
    do: get(String.to_existing_atom(name))

  def get(name) when is_atom(name) do
    GenServer.call(name, :get)
  end

  def get!(resource_or_name) do
    {:ok, logger} = get(resource_or_name)
    logger 
  end

  def new(args) when is_list(args) do
    with {:ok, pid} <- start_link(args),
      {:ok, logger} <- GenServer.call(pid, :get) do
        {:ok, logger}
    else
      error -> {:error, error}
    end
  end
end
