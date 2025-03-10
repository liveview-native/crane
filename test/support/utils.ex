defmodule Crane.Test.Utils do
  def pid_for(%{name: name}),
    do: Process.whereis(name)
end
