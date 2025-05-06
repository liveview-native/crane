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
    pending_forms: %{},
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

  def handle_join(%__MODULE__{} = view, %{"container" => container} = response, live_socket) do
    handle_join(view, Map.delete(response, "container"), live_socket)
  end

  def handle_join(%__MODULE__{} = view, %{"rendered" => rendered} = response, live_socket) do
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
      update(view, %{
        rendered: view.rendered,
        join_count: view.join_count,
        join_attempts: view.join_attempts
      })

      LiveSocket.send_to_receiver(live_socket, :view_tree)

      # maybe_recover_forms(view, markup, fn(view) ->
      #   # TODO: implement form recovery
      #   on_join_complete(view, response, markup, streams, events)
      # end)
    end)
  end

  # def on_join_complete(%__MODULE__{} = view, response, markup, streams, events) do
  #   live_path = Map.get(response, "live_patch")
  #
  #   if view.join_count > 1 or 
  # end

  defp maybe_recover_forms(%__MODULE__{} = view, markup, func) do
    func.(view)
  end

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
end
