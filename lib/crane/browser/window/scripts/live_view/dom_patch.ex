defmodule LiveView.DOMPatch do
  use LiveView.Constants, [
    :phx_component,
    :phx_prune,
    :phx_root_id,
    :phx_session,
    :phx_skip,
    :phx_magic_id,
    :phx_static,
    :phx_trigger_action,
    :phx_update,
    :phx_ref_src,
    :phx_ref_lock,
    :phx_stream,
    :phx_stream_ref,
    :phx_viewport_top,
    :phx_viewport_bottom
  ]

  defstruct [
    view: nil,
    live_socket: nil,
    container: nil,
    id: nil, 
    root_id: nil,
    markup: nil,
    streams: nil,
    stream_inserts: %{},
    stream_component_restore: %{},
    target_cid: nil,
    cid_patch?: false,
    pending_removes: [],
    phx_remove: nil,
    target_container: nil,
    callbacks: %{
      before_added: [],
      before_updated: [],
      before_phx_child_added: [],
      after_added: [],
      after_updated: [],
      after_discarded: [],
      after_phx_child_added: [],
      after_transitions_discarded: []
    },
    with_children: false,
    undo_ref: nil
  ]

  @behaviour Access
  defdelegate fetch(dom_patch, key), to: Map
  defdelegate get_and_update(dom_patch, key, function), to: Map
  defdelegate pop(dom_patch, key), to: Map

  import LiveView.Utils

  def new(opts) do
    dom_patch = struct(%__MODULE__{}, opts)
    {:ok, live_socket} = LiveSocket.get(dom_patch.view.live_view_name)
    cid_patch? = is_cid?(dom_patch.target_cid)
    target_container = if cid_patch?,
      do: target_cid_container(dom_patch, dom_patch.markup),
      else: dom_patch.container

    # TODO: fix
    # with_children = cond do
    #   Keyword.get(opts, :with_children) = with_children -> with_children
    #   Keyword.get(opts, :undo_ref) = undo_ref -> undo_ref
    #   true -> false
    # end

    {:ok, %__MODULE__{dom_patch |
      live_socket: live_socket,
      cid_patch?: cid_patch?,
      target_container: target_container,
      with_children: nil} #with_children}
    }
  end

  defp kind_callback(dom_patch, kind, callback) do
    callbacks =
      Map.get(dom_patch.callback, kind, [])
      |> List.insert_at(-1, callback)

    put_in(dom_patch, [:callbacks, kind], callbacks)
  end

  def do_before(%__MODULE__{} = dom_patch, kind, callback) do
    kind = String.to_existing_atom("before_#{kind}")
    kind_callback(dom_patch, kind, callback)
  end

  defp target_cid_container(%__MODULE__{} = dom_patch, markup) do
    # if is_cid_patch?(dom_patch) do
    #   nil
    # else
    #   [first | rest] = DOM.find_component_node_list(dom_patch.container, dom_patch.target_cid)
    #
    #   if rest == [] && DOM.child_node_length(markup) == 1 do
    #     first
    #   else
    #     first && first.parent_node
    #   end
    # end
  end

  def do_after(%__MODULE__{} = dom_patch, kind, callback) do
    kind = String.to_existing_atom("after_#{kind}")
    kind_callback(dom_patch, kind, callback)
  end

  defp kind_track(dom_patch, kind, args) do
    callbacks = get_in(dom_patch, [:callbacks, kind])
    Enum.each(callbacks, &(apply(&1, args)))
  end

  def track_before(%__MODULE__{} = dom_patch, kind, args) do
    kind = String.to_existing_atom("before_#{kind}")
    kind_track(dom_patch, kind, args)
  end

  def track_after(%__MODULE__{} = dom_patch, kind, args) do
    kind = String.to_existing_atom("after_#{kind}")
    kind_track(dom_patch, kind, args)
  end

  def mark_prunable_content_for_removal(%__MODULE__{} = dom_patch) do
    phx_update = LiveSocket.binding(dom_patch.live_socket, @phx_update)
    container = Floki.find_and_udpate(dom_patch.container, "[#{phx_update}=appennd] > *, [#{phx_update}=prepend] > *", fn
      {tag_name, attributes, children} ->
        attributes =
          Enum.into(attributes, %{})
          |> Map.merge(%{@phx_prune => true})
          |> Map.to_list()

        {tag_name, attributes, children}

      other -> other
    end)
  end

  def get_stream_insert(%__MODULE__{} = dom_patch, el) do
    if id = DOM.get_attribute(el, "id"),
      do: Map.get(dom_patch.stream_inserts, id, %{}),
      else: %{}
  end

  def set_stream_ref(el, ref) do
    
  end
end
