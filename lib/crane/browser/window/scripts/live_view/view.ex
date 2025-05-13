defmodule LiveView.View do
  alias LiveView.{
    DOM,
    LiveSocket,
    View.Rendered,
  }
  alias LiveView.Browser
  alias Crane.Browser.{
    Window,
    Window.History
  }

  use LiveView.Constants, [
    :events,
    :components,
    :consecutive_reloads,
    :phx_main,
    :phx_ref_loading,
    :phx_ref_lock,
    :phx_ref_src,
    :phx_static,
    :phx_sticky,
    :phx_session,
    :reply,
    :title,
  ]

  use Crane.Object,
    name_prefix: "lv:",
    owner: LiveSocket,
    window_name: nil,
    is_dead: false,
    flash: nil,
    parent: nil,
    root: nil,
    el: nil,
    id: nil,
    last_ack_ref: nil,
    child_joins: 0,
    loader_timer: nil,
    rendered: nil,
    disconnected_timer: nil,
    pending_diffs: [],
    pending_forms: MapSet.new([]),
    redirect: false,
    href: nil,
    join_count: 0,
    join_attempts: 0,
    join_pending: true,
    destroyed: false,
    join_callback: nil,
    stop_callback: &__MODULE__.default_stop_callback/1,
    pending_join_ops: nil,
    view_hooks: %{},
    form_submits: [],
    children: %{},
    forms_for_recovery: %{},
    channel: nil

  def default_stop_callback(view),
    do: view

  def start_link(opts) do
    name_prefix = %__MODULE__{}.name_prefix
    id = case DOM.get_attribute(opts[:el], "id") do
      nil -> Crane.Utils.generate_name(:root)
      id -> id
    end

    opts = Keyword.merge(opts, [
      id: id,
      pending_join_ops: opts[:parent] && nil || [],
      window_name: get_in(opts, [:live_socket, :window_name]),
      name: String.to_atom("#{name_prefix}#{id}")
    ])

    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def handle_call({:dispatch, function, args}, _from, %__MODULE__{} = view) do
    apply(__MODULE__, function, args ++ [view])
  end

  def handle_cast({:dispatch, function, args}, %__MODULE__{} = view) do
    apply(__MODULE__, function, args ++ [view])
  end

  def handle_cast({:push_pending_join_op, op}, %__MODULE__{pending_join_ops: pending_join_ops} = view) do
    {:noreply, %__MODULE__{view |
      pending_join_ops: List.insert_at(pending_join_ops, -1, op)
    }}
  end

  def handle_cast({:add_child_view, parent_view, child_view}, %__MODULE__{children: children} = view) do
    children = put_in(children, [parent_view.id, child_view.id], child_view.name)
    {:noreply, %__MODULE__{children: children}}
  end

  def join(%__MODULE__{} = view, %LiveSocket{} = live_socket) do
    live_socket = %LiveSocket{live_socket |
      socket: Slipstream.join(live_socket.socket, "lv:#{view.id}", join_params(live_socket, view, %{})),
    }

    {:ok, view, live_socket}
  end

  defp join_params(live_socket, view, params) do
    Map.merge(params, %{
      "redirect" => view.redirect && live_socket.href || nil,
      "url" => !view.redirect && live_socket.href || nil,
      "params" => LiveSocket.connect_params(live_socket, live_socket.params),
      "session" => DOM.get_attribute(view.el, @phx_session),
      "static" => DOM.get_attribute(view.el, @phx_static),
      "sticky" => DOM.has_attribute?(view.el, @phx_sticky)
    })
    |> Map.reject(&(is_nil(elem(&1, 1))))
  end

  def exec_new_mounted(%__MODULE__{} = view) do
    :ok
  end

  def handle_join(%{"container" => container} = response, %__MODULE__{} = view) do
    {:ok, view} = DOM.replace_root_container(view, Map.get(container, :tags), Map.get(container, :attrs))
    handle_join(Map.delete(response, "container"), view)
  end

  def handle_join(%{"rendered" => rendered} = response, %__MODULE__{} = view) do
    {:ok, window} = Window.get(view.window_name)

    view = %__MODULE__{view |
      child_joins: 0,
      join_pending: true,
      flash: nil
    }

    # view = if view.root == view,
    #   do: struct(view, forms_for_recovery: get_forms_for_recovery(view)),
    #    else: view

    {frame_state, _frame_opts} = History.current_frame(window.history)

    window = if is_main?(view) && frame_state == %{} do
      Browser.push_state(window, :replace, %{
        type: :patch,
        id: view.id,
        position: window.history.index
      })
    else
      window
    end

    # :ok = Browser.drop_local(live_socket.local_storage, window.location.pathname, @consecutive_reloads)

    view = apply_diff(view, :mount, rendered, fn(view, %{diff: diff, events: events}) ->
      view = %__MODULE__{view |
        rendered: %Rendered{view_id: view.id},
        join_count: view.join_count + 1,
        join_attempts: 0
      }
      
      {_diff, rendered} = Rendered.merge_diff(view.rendered, diff)

      view = %__MODULE__{view |
        rendered: rendered
      }

      {markup, streams} = render_container(view, nil, :join)

      {:ok, [{container_tag_name, container_attrs, container_children} = container]} = LiveViewNative.Template.Parser.parse_document(markup,
        strip_comments: true,
        text_as_node: true,
        inject_identity: true)

      body = Floki.traverse_and_update(window.view_trees.body, fn
        {tag_name, attrs, children} when is_binary(tag_name) ->
          if {"id", view.id} in attrs do
            {tag_name, attrs, container_children}
          else
            {tag_name, attrs, children}
          end

        other -> other
      end)

      container = build_container(view, {container_tag_name, container_attrs, container_children})

      Window.update(window, view_trees: Map.merge(window.view_trees, %{body: body, container: container}))

      view = %__MODULE__{view |
        rendered: view.rendered,
        join_count: view.join_count,
        join_attempts: view.join_attempts
      }

      :ok = LiveSocket.send_to_receiver(view.live_socket_name, :view_tree)

      {:noreply, view}

      # maybe_recover_forms(view, live_socket, markup, fn(view) ->
      #   # TODO: implement form recovery
        # on_join_complete(view, response, markup, streams, events)
      # end)
    end)
  end

  # defp on_join_complete(%__MODULE__{} = view, response, markup, streams, events) do
  #   live_patch = Map.get(response, :live_patch)
  #
  #   view = if view.join_count > 1 or view.parent and !is_join_pending?(view.parent) do
  #     apply_join_patch(view, live_patch, markup, streams, events)
  #   else
  #     DOM.find_phx_children_in_fragment(markup, view.id)
  #     |> Enum.reduce({view, []}, fn(to_el, {view, children}) ->
  #       from_el = to_el.id and Floki.find(view.el)
  #       phx_static = from_el && DOM.get_attribute(from_el, @phx_static)
  #       to_el = if from_el,
  #         do: DOM.set_attributes(to_el, %{@phx_static => phx_static}),
  #         else: to_el
  #
  #       case join_child(view, to_el) do
  #         {view, true} ->
  #           {view, [to_el | children]}
  #         {view, false} ->
  #           {view, children}
  #       end
  #     end)
  #     |> case do
  #       {view, []} when is_list(children) ->
  #         view = if view.parent do
  #           cb = {view, fn ->
  #             apply_join_patch(view, live_patch, markup, streams, events)
  #           end}
  #           :ok = View.push_pending_join_op(view, cb)
  #           View.ack_join(view.parent)
  #         else
  #           view =
  #             view
  #             |> on_all_child_joins_complete()
  #             |> apply_join_patch(live_patch, markup, streams, events)
  #         end
  #       {view, new_children}
  #         cb = fn(view) ->
  #           apply_join_patch(view, live_patch, markup, streams, events)
  #         end
  #
  #         :ok = View.push_pending_join_op(view, cb)
  #
  #     end
  #   end
  #
  #   {:noreply, view}
  # end
  #
  # def push_pending_join_op(%__MODULE__{root_name: root_name} = view, cb),
  #   do: GenServer.cast(root_name, {:push_pending_join_op, {view, cb}})
  #
  # defp add_child_view(%__MODULE__{root_name: root_name} = view, %__MODULE__{} = new_view),
  #   do: GenServer.cast(root_name, {:add_child_view, view, new_view})
  #
  # defp is_join_pending?(%__MODULE__{join_pending: join_pending}),
  #   do: !!join_pending
  #
  # defp ack_join(%__MODULE__{} = view) do
  #   view = Map.update(view, :child_joins, &(&1 - 1))
  #
  #   if view.child_joins == [] do
  #     if view.parent do
  #       parent = View.ack_join(view.parent) 
  #       Map.put(view, :parent, parent)
  #     else
  #       on_all_child_joins_complete(view)
  #     end
  #   else
  #     view
  #   end
  # end
  #
  # defp on_all_child_joins_complete(%__MODULE__{} = view) do
  #   view = %__MODULE__{view |
  #     pending_forms: MapSet.new([]),
  #     forms_for_recovery: %{}
  #   }
  #
  #   view.join_callback.(fn(view) ->
  #     for {target_view, op} <- view.pending_join_ops do
  #       if View.is_destroyed?(target_view),
  #         do: op.(target_view)
  #     end
  #
  #     Map.update(view, :pending_join_ops, [])
  #   end)
  # end
  #
  # defp is_destroyed?(%__MODULE__{destroyed: destroyed}),
  #   do: destroyed
  #
  # defp join_child(%__MODULE__{} = view, el) do
  #   case get_child_by_id(view, el.id) do
  #     nil ->
  #       {:ok, new_view} = LiveSocket.new_view(view.live_socket_name, el: el, parent_view: view)
  #       :ok = View.add_child_view(view, new_view)
  #       # view = put_in(view, [:root, :children, view.id, new_view.id], new_view)
  #       View.join(new_view)
  #       {view, true}
  #     _child ->
  #       {view, false}
  #   end
  # end
  #
  # defp get_child_by_id(%__MODULE__{root: root, id: id}, child_id),
  #   do: get_in(root, [:children, id, child_id])
  #
  # defp apply_join_patch(%__MODULE__{} = view, live_patch, markup, streams, events) do
  #   view = attach_true_doc_el(view)
  #   # patch =
  #   #   DOMPatch.new(view, view.el, view.id, markup, streams, nil)
  #   #   |> DOMPatch.mark_prunable_content_for_removal()
  #
  #   view =
  #     view
  #     # |> perform_patch(patch, false, true)
  #     |> join_new_children()
  #     |> exec_new_mounted()
  #
  #   view = Map.put(view, :join_pending, false)
  #   LiveSocket.dispatch_events(view.live_socket_name, events)
  #   view = apply_pending_updates(view)
  #
  #   if live_patch,
  #     do: LiveSocket.history_patch(view.live_socket_name, live_patch.to, live_patch.kind)
  #
  #   view = if view.join_count > 1,
  #     do: trigger_reconnected(view),
  #     else: view
  #
  #   stop_callback(view)
  # end
  #
  # defp trigger_reconnected(%__MODULE__{} = view) do
  #   # TODO
  #   view
  # end
  #
  # defp apply_pending_update(view) do
  #   {:ok, live_socket} = LiveSocket.get(view.live_socket_name)
  #
  #   if !(LiveSocket.has_pending_link?(live_socket) && is_main?(view.root)) do
  #     Enum.reduce(view.pending_diff, view, fn({diff, events}, view) ->
  #       View.update(view, diff, events)
  #     end)
  #     |> Map.put(:pending_diffs, [])
  #     |> each_child(fn(child) -> View.apply_pending_updates(view) end)
  #   else
  #     view
  #   end
  # end
  #
  # defp each_child(%__MODULE__{} = view, callback) do
  #   children =
  #     view
  #     |> get_in([:root, :children])
  #     |> Map.get(view.id, %{})
  #     |> Enum.into(%{}, fn({id, _child}, view) ->
  #       child =
  #         view
  #         |> View.get_child_by_id(id)
  #         |> callback.()
  #
  #       {id, child}
  #     end)
  # end

  # def update(%__MODULE__{} = view, diff, events) do
  #   {:ok, live_socket} = LiveSocket.get(view.live_socket_name)
  #
  #   if is_join_pending?(view) or (LiveSocket.has_pending_link?(live_socket) and is_main?(view.root)) do
  #     %__MODULE__{view |
  #       pending_diffs: List.insert_at(view.pending_diffs, {diff, events})
  #     }
  #   else
  #     {_diff, rendered} = Rendered.merge_diff(view.rendered, diff)
  #     phx_children_added = false
  #
  #     view = %__MODULE__{view | rendered: rendered}
  #
  #     {view, phx_children_added} =
  #       cond do
  #       Rendered.is_component_only_diff?(view.rendered, diff) ->
  #         LiveSocket.time(live_socket, "component patch complete", fn() ->
  #           parent_cids = DOM.find_existing_parent_cids(view.el, Rendered.component_cids(view.rendered, diff))
  #           Enum.reduce(parent_cids, {view, phx_children_added}, fn(parent_cid, {view, phx_children_added}) ->
  #             phx_children_added = if component_patch(Rendered.get_component(view.rendered, diff, parent_cid), parent_cid),
  #               do: true,
  #               else: phx_children_added
  #
  #             {view, phx_children_added}
  #           end)
  #         end)
  #
  #       !is_empty?(diff) ->
  #         LiveSocket.time(live_socket, "full patch complete", fn() ->
  #           {markup, streams} = Rendered.render_container(view.rendered, diff, "update")
  #           dom_patch = DOMPatch.new(view, view.el, view.id, markup, streams, nil)
  #           phx_children_added = perform_patch(view, dom_patch, true)
  #           {view, phx_children_added}
  #         end)
  #
  #       else
  #         {view, phx_children_added}
  #       end
  #
  #     LiveSocket.dispatch_events(live_socket, events)
  #
  #     if phx_chldren_added,
  #       do: join_new_children(view),
  #       else: view
  #   end
  # end
  #
  # defp join_new_children(view) do
  #
  # end

  defp attach_true_doc_el(%__MODULE__{} = view) do
    el = DOM.by_id(view.id)
    el = DOM.set_attributes(el, %{@phx_root_id => view.root.id})
    Map.put(view, :el, el)
  end

  def handle_diff(diff, events, %__MODULE__{} = view) do
    {_diff, rendered} = Rendered.merge_diff(view.rendered, diff)

    view = %__MODULE__{view |
      rendered: rendered
    }

    {markup, streams} = render_container(view, nil, :join)

    {:ok, [{container_tag_name, container_attrs, container_children}]} = LiveViewNative.Template.Parser.parse_document(markup,
      strip_comments: true,
      text_as_node: true,
      inject_identity: true)

    # {:ok, live_socket} = LiveSocket.get(view.live_socket_name)
    {:ok, window} = Window.get(view.window_name)

    body = Floki.traverse_and_update(window.view_trees.body, fn
      {tag_name, attrs, children} when is_binary(tag_name) ->
        if {"id", view.id} in attrs do
          {tag_name, attrs, container_children}
        else
          {tag_name, attrs, children}
        end

      other -> other
    end)

    container = build_container(view, {container_tag_name, container_attrs, container_children})

    Window.update(window, view_trees: Map.merge(window.view_trees, %{body: body, container: container}))

    view = %__MODULE__{view |
      rendered: view.rendered,
      join_count: view.join_count,
      join_attempts: view.join_attempts
    }

    LiveSocket.send_to_receiver(view.live_socket_name, :view_tree)

    {:noreply, view}
  end

  defp build_container(%__MODULE__{id: id}, {tag_name, attributes, children}),
    do: {tag_name, [{"id", id}] ++ attributes, children}

  def handle_redirect(payload, %__MODULE__{} = view) do
    cb = fn(view) ->
      View.on_redirect(view, payload)
    end

    # if is_join_pending?(view) do
    #   View.push_pending_join_ops(view.root, {view, cb})
    # else
    #   {:ok, live_socket} = LiveSocket.get(view.live_socket_name)
    #   live_socket = LiveSocket.request_dom_update(live_socket, fn() -> cb(view) end)
    #   LiveSocket.update(live_socket, %{transitions: live_socket.transitions})
    # end

    {:noreply, view}
  end

  def handle_live_patch(payload, %__MODULE__{} = view) do
    cb = fn(view) ->
      View.on_live_patch(view, payload)
    end

    # if is_join_pending?(view) do
    #   View.push_pending_join_ops(view.root, {view, cb})
    # else
    #   {:ok, live_socket} = LiveSocket.get(view.live_socket_name)
    #   live_socket = LiveSocket.request_dom_update(live_socket, fn() -> cb(view) end)
    #   LiveSocket.update(live_socket, %{transitions: live_socket.transitions})
    # end

    {:nopley, view}
  end

  def handle_live_redirect(payload, %__MODULE__{} = view) do
    cb = fn(view) ->
      View.on_live_redirect(view, payload)
    end

    # if is_join_pending?(view) do
    #   View.push_pending_join_ops(view.root, {view, cb})
    # else
    #   {:ok, live_socket} = LiveSocket.get(view.live_socket_name)
    #   live_socket = LiveSocket.request_dom_update(live_socket, fn() -> cb(view) end)
    #   LiveSocket.update(live_socket, %{transitions: live_socket.transitions})
    # end

    {:nopley, view}
  end

  defp on_redirect(%__MODULE__{} = view, payload) do
    to = Map.get(payload, "to")
    flash = Map.get(payload, "flash")
    reload_token = Map.get(payload, "reloadToken")

    {:ok, live_socket} = LiveSocket.redirect(view.live_socket_name, to, flash, reload_token)

    view
  end

  defp on_live_redirect(%__MODULE__{} = view, redir) do
    to = Map.get(redir, "to")
    flash = Map.get(redir, "flash")
    reload_token = Map.get(redir, "reloadToken")

    
  end

  def handle_event(%__MODULE__{} = view, event, live_socket) do
    {:ok, live_socket}
  end

  # def on_join_complete(%__MODULE__{} = view, response, markup, streams, events) do
  #   live_path = Map.get(response, "live_patch")
  #
  #   if view.join_count > 1 or 
  # end

  def binding(%LiveSocket{} = live_socket, kind),
    do: LiveSocket.binding(live_socket, kind)

  # defp maybe_recover_forms(%__MODULE__{} = view, %LiveSocket{} = live_socket, markup, func) do
  #   phx_change = binding(live_socket, :change)
  #   old_forms = view.root.forms_for_recovery
  #
  #   [root_el] = LiveViewNative.Template.Parser.parse_document!(markup,
  #     strip_comments: true,
  #     text_as_node: true,
  #     inject_identity: true)
  #
  #
  #   new_attributes = %{
  #     "id" => view.id,
  #     @phx_root_id => view.root.id,
  #     @phx_session => get_session(view),
  #     @phx_static => get_static(view)
  #   }
  #
  #   new_attributes =
  #     if is_nil(view.parent),
  #     do: new_attributes,
  #     else: Map.put(new_attributes, @phx_parent_id, view.parent.id)
  #
  #   root_el = DOM.set_attributes(root_el, new_attributes)
  #
  #   DOM.all(root_el, "form")
  #   |> Stream.filter(&(&1.id && Map.get(old_forms, &1.id)))
  #   |> Stream.filter(&(MapSet.member?view.pending_forms, &1.id))
  #   |> Stream.filter(&(DOM.get_attribute(Map.get(old_forms))))
  #   func.(view)
  # end

  def is_main?(name) when is_atom(name) do
    case View.get(name) do
      {:ok, view} -> is_main?(view)
      _other -> false
    end
  end

  def is_main?(%__MODULE__{el: el}),
    do: DOM.has_attribute?(el, @phx_main)

  def drop_pending_refs(%__MODULE__{} = view, %Window{} = window) do
    document = Floki.traverse_and_update(window.view_trees.document, fn 
      {tag_name, attrs, children} ->
        cond do
         {@phx_ref_src, view.ref_src} in attrs ->
            attrs = Enum.reject(attrs, fn({name, _value}) -> name in [@phx_ref_loading, @phx_ref_src, @phx_ref_lock] end)
            {tag_name, attrs, children}
          false ->
            {tag_name, attrs, children}
        end

      other -> other
    end)

    %Window{window | view_trees: Fuse.find_view_trees(document)}
  end

  defp render_container(%__MODULE__{} = view, diff, kind) do
    {:ok, live_socket} = LiveSocket.get(view.live_socket_name)

    LiveSocket.time(live_socket, "to_string diff #{kind}", fn ->
      {tag_name, _attrs, _children} = view.el

      cids = if diff,
        do: Rendered.component_cids(diff),
        else: nil

      {:ok, markup, streams} = Rendered.to_string(view.rendered, cids)
      {"<#{tag_name}>#{markup}</#{tag_name}>", streams}
    end)
  end

  defp apply_diff(%__MODULE__{} = view, _type, raw_diff, func) do
    {diff, reply, events, _title} = Rendered.extract(raw_diff)
    func.(view, %{diff: diff, reply: reply, events: events})
  end

  def get_session(%__MODULE__{el: el}),
    do: DOM.get_attribute(el, @phx_session)

  def get_static(%__MODULE__{el: el}) do
    if val = DOM.get_attribute(el, @phx_static) == "",
      do: nil,
      else: val
  end

  def dispatch(topic, event, args) when is_binary(topic),
    do: dispatch(String.to_existing_atom(topic), event, args)
  def dispatch(topic, event, args),
    do: GenServer.cast(topic, {:dispatch, event, args})
end
