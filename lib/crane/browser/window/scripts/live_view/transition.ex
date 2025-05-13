defmodule LiveView.TransitionSet do
 defstruct [
    transitions: MapSet.new([]),
    pending_ops: []
  ]

  def reset(%__MODULE__{transitions: transitions} = transition_set) do
    Enum.each(transitions, fn(timer_ref) ->
      Process.cancel_timer(timer_ref)
    end)

    transition_set
    |> Map.put(:transitions, MapSet.new([]))
    # |> flush_pending_ops()
  end

  def do_after(%__MODULE__{} = transition_set, callback) do
    if size(transition_set) == 0,
      do: callback.(transition_set),
      else: push_pending_op(transition_set, callback)
  end

  def add_transition(%__MODULE__{} = transition_set, time, on_start, on_done) do
    on_start.()

    {:ok, timer_ref} = :timer.send_after(time, self(), {:transition_timeout, fn(transition_set, timer_ref) ->
      transition_set = MapSet.delete(transition_set, timer_ref)
      on_done.()
    end})

    MapSet.add(transition_set, timer_ref)
  end

  defp push_pending_op(%__MODULE__{} = transition_set, op),
    do: %__MODULE__{transition_set |
      pending_ops: List.insert_at(transition_set.pending_ops, -1, op)
    }

  def size(%__MODULE__{transitions: transitions}),
    do: MapSet.size(transitions)

  defp flush_pending_opts(%__MODULE__{} = transition_set) do
    if size(transition_set) > 0 do 
      transition_set
    else
      case List.pop_at(transition_set.pending_ops, 0) do
        {nil, []} -> transition_set
        {op, pending_ops} ->
          op.()
          flush_pending_opts(%__MODULE__{transition_set | pending_ops: pending_ops})
      end
    end
  end
end
