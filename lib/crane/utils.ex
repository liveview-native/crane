defmodule Crane.Utils do
  def generate_name(type) when is_atom(type),
    do: generate_name(Atom.to_string(type))
  def generate_name(type) do
    type <> "-" <>
    (:crypto.hash(:sha, "#{:erlang.system_time(:nanosecond)}")
    |> Base.encode32(case: :lower))
    |> String.to_atom()
  end

  def get_reference_names(refs, type) do
    Enum.filter(refs, fn({_ref, name}) ->
      case Atom.to_string(name) do
        ^type <> "-" <> _id -> true
        _other -> false
      end
    end)
  end

  def monitor(reffable, refs) do
    pid = Process.whereis(reffable.name)
    ref = Process.monitor(pid)
    # I put the name as a string because the atom
    # value is only used once when tearing down the monitored
    # prcess but the string match in other functions
    # is used frequently
    # If that balance ever changes this should change to
    # an atom by default
    Map.put(refs, ref, Atom.to_string(reffable.name))
  end

  def subscribe(topic) do
    pubsub = Application.get_env(:crane, :pubsub, PhoenixPlayground.PubSub)
    Phoenix.PubSub.subscribe(pubsub, topic)
  end

  def broadcast(topic, message) do
    pubsub = Application.get_env(:crane, :pubsub, PhoenixPlayground.PubSub)
    Phoenix.PubSub.broadcast(pubsub, topic, message)
  end
end
