defmodule Crane.Utils do
  def generate_name(type) when is_atom(type),
    do: generate_name(Atom.to_string(type))
  def generate_name(type) do
    type <>
    (:crypto.hash(:sha, "#{:erlang.system_time(:nanosecond)}")
    |> Base.encode32(case: :lower))
    |> String.to_atom()
  end
end
