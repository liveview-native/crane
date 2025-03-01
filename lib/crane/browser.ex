defmodule Crane.Browser do
  use DynamicSupervisor 

  alias Crane.{Window}

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def open_window do
    DynamicSupervisor.start_child(__MODULE__, {Window, []})
  end

  def windows do
    Task.Supervisor.children(__MODULE__)
  end
end
