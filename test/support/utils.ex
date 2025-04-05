defmodule Crane.Test.Utils do
  def pid_for(%{name: name}),
    do: Process.whereis(name)

  def start_pubsub(config) do
    ExUnit.Callbacks.start_supervised!({Phoenix.PubSub, name: config.test})
  end
end
