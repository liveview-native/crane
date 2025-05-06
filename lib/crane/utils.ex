defmodule Crane.Utils do
  def generate_name(prefix) when is_atom(prefix),
    do: generate_name(Atom.to_string(prefix))
  def generate_name(prefix) do
    prefix <> "-" <>
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

  def get_reference_object(refs, type, func) do
    type = Atom.to_string(type)

    Enum.reduce(refs, [], fn({_ref, name}, acc) ->
      case Atom.to_string(name) do
        ^type <> "-" <> _id = name ->
          {:ok, object} = func.(name)
          [object | acc]
        _other -> acc
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
    Map.put(refs, ref, reffable.name)
  end

  def demonitor(ref, refs) do
    Process.demonitor(ref)
    Map.delete(refs, ref)
  end

  def subscribe(%{name: topic}),
    do: subscribe(topic)

  def subscribe(topic) when is_atom(topic),
    do: Atom.to_string(topic) |> subscribe()

  def subscribe(topic) do 
    pubsub = Application.get_env(:crane, :pubsub, PhoenixPlayground.PubSub)
    :ok = Phoenix.PubSub.subscribe(pubsub, topic)
  end

  def unsubscribe(%{name: topic}),
    do: unsubscribe(topic)

  def unsubscribe(topic) when is_atom(topic),
    do: Atom.to_string(topic) |> unsubscribe()

  def unsubscribe(topic) do
    pubsub = Application.get_env(:crane, :pubsub, PhoenixPlayground.PubSub)
    :ok = Phoenix.PubSub.unsubscribe(pubsub, topic)
  end

  def broadcast(%{name: topic}, message),
    do: broadcast(topic, message)

  def broadcast(topic, message) when is_atom(topic),
    do: Atom.to_string(topic) |> broadcast(message)

  def broadcast(topic, message) do
    pubsub = Application.get_env(:crane, :pubsub, PhoenixPlayground.PubSub)
    :ok = Phoenix.PubSub.broadcast(pubsub, topic, message)
  end
end
