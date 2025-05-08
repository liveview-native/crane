defmodule LiveView.View do
  alias LiveView.{
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
    # stop_callback: (fn() -> nil end),
    pending_join_ops: nil,
    view_hooks: %{},
    form_submits: [],
    children: %{},
    forms_for_recovery: %{},
    channel: nil

  def start_link(opts) do
    name_prefix = %__MODULE__{}.name_prefix
    id = has_attribute(opts[:el], "id")
    opts = Keyword.merge(opts, [
      id: id,
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
      "session" => has_attribute(view.el, @phx_session),
      "static" => has_attribute(view.el, @phx_static),
      "sticky" => !!has_attribute(view.el, @phx_sticky)
    })
    |> Map.reject(&(is_nil(elem(&1, 1))))
  end

  def exec_new_mounted(%__MODULE__{} = view) do
    :ok
  end

  def handle_join(%{"container" => container} = response, live_socket, %__MODULE__{} = view) do
    {:ok, view} = DOM.replace_root_container(view, Map.get(container, :tags), Map.get(container, :attrs))
    handle_join(Map.delete(response, "container"), live_socket, view)
  end

  def handle_join(%{"rendered" => rendered} = response, live_socket, %__MODULE__{} = view) do
    {:ok, window} = Window.get(live_socket.window_name)
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

    :ok = Browser.drop_local(live_socket.local_storage, window.location.pathname, @consecutive_reloads)

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

      {markup, streams} = render_container(view, live_socket, nil, :join)

      {:ok, [{_container_tag_name, _container_attrs, container_children}]} = LiveViewNative.Template.Parser.parse_document(markup,
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

      Window.update(window, view_trees: Map.put(window.view_trees, :body, body))
      view = %__MODULE__{view |
        rendered: view.rendered,
        join_count: view.join_count,
        join_attempts: view.join_attempts
      }

      {:ok, live_socket} = LiveSocket.send_to_receiver(live_socket, :view_tree)

      {:reply, {:ok, live_socket}, view}

      # maybe_recover_forms(view, live_socket, markup, fn(view) ->
      #   # TODO: implement form recovery
        # on_join_complete(view, live_socket, response, markup, streams, events)
      # end)
    end)
  end

  # defp on_join_complete(%__MODULE__{} = view, %LiveSocket{} = live_socket, response, markup, streams, events) do
  #   live_patch = Map.get(response, :live_patch)
  #
  #   {view, live_socket} = if view.join_count > 1 or view.parent and !is_join_pending?(view.parent) do
  #       apply_join_patch(view, live_socket, live_patch, markup, streams, events)
  #   else
  #     DOM.find_phx_children_in_fragment(markup, view.id)
  #     |> Enum.reduce({view, live_socket, []}, fn(to_el, {view, live_socket, children}) ->
  #       from_el = to_el.id and Floki.find(view.el)
  #       phx_statix = from_el && DOM.get_attribute(from_el, @phx_static)
  #       to_el = if from_el,
  #         do: DOM.set_attributes(to_el, %{@phx_static => phx_static}),
  #         else: to_el
  #
  #       case join_child(view, live_socket, to_el) do
  #         {view, live_socket, true} ->
  #           {view, live_socket, [to_el | children]}
  #         {view, live_socket, false} ->
  #           {view, live_socket, children}
  #       end
  #     end)
  #     |> case do
  #       {view, live_socket, []} ->
  #         {view, live_socket}
  #       children when is_list(children) ->
  #         view = if view.parent do
  #           op = {view, fn ->
  #             apply_join_patch(view, live_socket, live_patch, markup, streams, event)
  #           end}
  #           view = put_in(view, [:root, :pending_join_opts], view.root.pending_join_opts ++ [op])
  #           View.ack_join(parent)
  #         else
  #           view =
  #             view
  #             |> on_all_child_joins_complete()
  #             |> apply_join_patch(live_socket, live_patch, markup, streams, events)
  #         end
  #
  #         op = {view, fn ->
  #           apply_join_patch(view, live_socket, live_patch, markup, streams, event)
  #         end}
  #
  #         view = put_in(view, [:root, :pending_join_opts], view.root.pending_join_opts ++ [op])
  #
  #     end
  #   end
  #
  #   {:reply, {:ok, live_socket}, view}
  # end
  #
  # defp ack_join(%__MODULE__{} = view) do
  #   view = Map.update(view, :child_joins, &(&1 - 1))
  #
  #   if child_joins == 0 do
  #     if view.parent do
  #       parent = View.ack_join(parent) 
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
  #         do: op.()
  #     end
  #
  #     Map.update(view, :pending_join_ops, [])
  #   end)
  # end
  #
  # defp is_destroyed?(%__MODULE__{destroyed: destroyed}),
  #   do: destroyed
  #
  # defp join_child(%__MODULE__{} = view, %LiveSocket{} = live_socket, el) do
  #   case get_child_by_id(el.id) do
  #     nil ->
  #       {:ok, new_view, live_socket} = LiveSocket.new_view(live_socket, el: el, parent_view: view)
  #       view = put_in(view, [:root, :children, view.id, new_view.id], new_view)
  #       View.join(new_view, live_socket)
  #       {view, live_socket, true}
  #     _child ->
  #       {view, live_socket, false}
  #   end
  # end
  #
  # defp apply_join_patch(%__MODULE__{} = view, %LiveSocket{} = live_socket, markup, streams, events) do
  #   view = attach_true_doc_el(view)
  #   patch =
  #     DOMPatch.new(view, view.el, view.id, markup, stream, nil)
  #     |> DOMPatch.mark_prunable_content_for_removal()
  #
  #   view =
  #     view
  #     |> perform_patch(patch, false, true)
  #     |> join_new_children()
  #     |> exec_new_mounted()
  #
  #   view = Map.put(view, :join_pending, false)
  #   live_socket = LiveSocket.dispatch_events(live_socket, events)
  #   view = apply_pending_updates(view)
  #
  #   live_socket = if live_patch,
  #     do: LiveSocket.history_patch(live_socket, live_patch.to, live_patch.kind),
  #     else: live_socket
  #
  #   view = if view.join_count > 1,
  #     do: trigger_reconnected(view),
  #     else: view
  #
  #   stop_callback(view)
  #
  #   {view, live_socket}
  # end

  def handle_diff(diff, events, %__MODULE__{} = view) do
    {_diff, rendered} = Rendered.merge_diff(view.rendered, diff)

    view = %__MODULE__{view |
      rendered: rendered
    }

    {:ok, live_socket} = LiveSocket.get(view.live_socket_name)
    {:ok, window} = Window.get(live_socket.window_name)

    {markup, streams} = render_container(view, live_socket, nil, :join)

    {:ok, [{_container_tag_name, _container_attrs, container_children}]} = LiveViewNative.Template.Parser.parse_document(markup,
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

    Window.update(window, view_trees: Map.put(window.view_trees, :body, body))

    view = %__MODULE__{view |
      rendered: view.rendered,
      join_count: view.join_count,
      join_attempts: view.join_attempts
    }

    LiveSocket.send_to_receiver(live_socket, :view_tree)

    {:noreply, view}
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

  def is_main?(%__MODULE__{el: el}) do
    !!has_attribute(el, @phx_main)
  end

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

  defp render_container(%__MODULE__{} = view, %LiveSocket{} = live_socket, diff, kind) do
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

  defp has_attribute(el, attribute) do
    Floki.attribute(el, attribute) |> List.first()
  end

  def get_session(%__MODULE__{el: el}),
    do: DOM.get_attribute(el, @phx_session)

  def get_static(%__MODULE__{el: el}) do
    if val = DOM.get_attribute(el, @phx_static) == "",
      do: nil,
      else: val
  end
end
