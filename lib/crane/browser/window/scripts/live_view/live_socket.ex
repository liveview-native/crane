defmodule LiveView.LiveSocket do
  alias Crane.{
    Browser,
    Browser.Window
  }
  alias LiveView.{
    DOM,
    TransitionSet,
    View
  }

  use LiveView.Constants, [
    :binding_prefix,
    :defaults,
    :failsafe_jitter,
    :loader_timeout,
    :max_reloads,
    :phx_lv_history_position,
    :phx_lv_profile,
    :phx_main,
    :phx_parent_id,
    :phx_reload_status,
    :phx_session,
    :phx_static,
    :phx_sticky,
    :reload_jitter_max,
    :reload_jitter_min,
    :transports
  ]

  use Crane.Object,
    owner: Window,
    socket: nil,
    receiver: nil,
    unloaded: false,
    binding_prefix: @binding_prefix,
    opts: nil,
    params: %{},
    view_logger: nil,
    matadata_callbacks: %{},
    defaults: @defaults,
    prev_active: nil,
    silenced: false,
    main_name: nil,
    outgoing_main_el: nil,
    click_started_at_target: nil,
    link_ref: nil,
    roots: %{},
    href: nil,
    pending_link: nil,
    curent_location: nil,
    hooks: %{},
    uploaders: %{},
    loader_timeout: @loader_timeout,
    disconnected_timeout: @disconnected_timeout,
    reload_with_jitter_timer: nil,
    max_reloads: @max_reloads,
    reload_jittter_min: @reload_jitter_min,
    reload_jitter_max: @reload_jitter_max,
    failsafe_jitter: @failsafe_jitter,
    local_storage: %{},
    session_storage: %{},
    bound_top_level_events: false,
    bound_event_names: [],
    server_close_ref: nil,
    dom_callbacks: %{},
    transitions: %TransitionSet{},
    current_history_position: 0

  defchild view: View

  @behaviour Access
  defdelegate fetch(live_socket, key), to: Map
  defdelegate get_and_update(live_socket, key, function), to: Map
  defdelegate pop(live_socket, key), to: Map

  def start_link(opts) when is_list(opts) do
    opts =
      Keyword.put_new_lazy(opts, :name, fn ->
        Crane.Utils.generate_name(:socket)
      end)

    Slipstream.start_link(__MODULE__, opts, name: opts[:name])
  end

  @impl true
  def init(opts) do
    {:ok, live_socket, {:continue, {:init, opts}}} = super(opts)
    {:ok, window} = Window.get(live_socket.window_name)

    {:ok, socket} =
      Slipstream.connect(
        uri: live_view_url(window.location.href, opts[:url], connect_params(live_socket, live_socket.params)),
        json_parser: LiveView.JSON,
        headers: opts[:headers])

    refs = if live_socket.receiver do
      ref = Process.monitor(live_socket.receiver)
      Map.put(live_socket.refs, ref, {:receiver, live_socket.receiver})
    else
      live_socket.refs
    end
  
    {:ok, struct(live_socket, opts ++ [socket: socket, opts: opts, href: window.location.href])}
  end

  defp live_view_url(href, path, params) do
    uri = URI.parse(href)

    query = Map.merge(Plug.Conn.Query.decode(uri.query || ""), params)

    %URI{uri | scheme: upgrade_scheme(uri.scheme), path: live_view_path(uri.path, path), query: Plug.Conn.Query.encode(query)}
    |> URI.to_string()
  end

  def connect_params(_live_socket, params) do
    Map.merge(params, %{
      "_mounts" => 0,
      "_mount_attempts" => 0,
      "_live_referer" => "undefined",
      "_track_static" => %{},
      "vsn" => "2.0.0"
    })
  end

  defp upgrade_scheme("http"),
    do: "ws"
  defp upgrade_scheme("https"),
    do: "wss"

  defp live_view_path(uri_path, path),
    do: ~s'/#{Enum.reject([uri_path, path, "websocket"], &(is_nil(&1))) |> Path.join()}'

  @impl true
  def handle_call(:get, _from, live_socket),
    do: {:reply, {:ok, live_socket}, live_socket}

  def handle_message(topic, "diff", payload, live_socket) do
    {events, diff} = Map.pop(payload, :e, [])
    :ok = View.dispatch(topic, :handle_diff, [diff, events])
    {:ok, live_socket}
  end

  def handle_message(topic, "redirect", payload, live_socket) do
    :ok = View.dispatch(topic, :handle_redirect, [payload])
    {:ok, live_socket}
  end

  def handle_mesage(topic, "live_patch", redir, live_socket) do
    :ok = View.dispatch(topic, :handle_live_patch, [redir])
    {:ok, live_socket}
  end

  def handle_message(topic, "live_redirect", redir, live_socket) do
    :ok = View.dispatch(topic, :handle_live_redirect, [redir])
    {:ok, live_socket}
  end

  def handle_call({:assign, func}, %__MODULE__{socket: socket} = live_socket) when is_function(func, 1) do
    socket = func.(socket)

    %__MODULE__{live_socket |
      socket: socket
    }
  end

  def handle_call({:assign, assigns}, %__MODULE__{socket: socket} = live_socket) do
    socket = Slipstream.Socket.assign(socket, assigns)
    {:reply, %__MODULE__{live_socket | socket: socket}}
  end

  def handle_call({:attach_receiver, receiver}, _from, websocket) do
    {:reply, :ok, %__MODULE__{websocket | receiver: receiver}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %__MODULE__{refs: refs} = live_socket) when is_map_key(refs, ref) do
    live_socket = case Map.pop(refs, ref) do
      {{:receiver, _receiver}, refs} ->
          %__MODULE__{live_socket | receiver: nil, refs: refs}
      {_name, refs} ->
          %__MODULE__{live_socket | refs: refs}
    end

    {:noreply, live_socket}
  end

  def handle_info({:__slipstream_event__, event}, %__MODULE__{} = live_socket) do
    LiveView.LiveSocket.Callback.dispatch(__MODULE__, event, live_socket)
  end

  def handle_info({:__slipstream_command, %Slipstream.Commands.OpenConnection{} = cmd}, %__MODULE__{socket: socket} = live_socket) do
    socket = Slipstream.TelemetryHelper.begin_connect(socket, cmd.config)

    _ = Slipstream.CommandRouter.route_command(cmd)

    {:noreply, %__MODULE__{live_socket | socket: socket}}
  end

  def handle_info({:__slipstream_command, %Slipstream.Commands.JoinTopic{} = cmd}, %__MODULE__{socket: socket} = live_socket) do
    socket = Slipstream.TelemetryHelper.begin_join(socket, cmd.topic, cmd.payload)

    _ = Slipstream.CommandRouter.route_command(cmd)

    {:noreply, %__MODULE__{live_socket | socket: socket}}
  end

  def handle_connect(%__MODULE__{} = live_socket) do
    {:ok, window} = Window.get(live_socket.window_name)

    :ok = reset_reload_status(window)

    {
      :ok,
      live_socket
      |> join_root_views(window.view_trees.document)
      |> join_dead_view(window.view_trees)
    }
  end

  def handle_join(topic, response, live_socket) do
    :ok = GenServer.cast(String.to_existing_atom(topic), {:dispatch, :handle_join, [response]})
    {:ok, live_socket}
  end

  def handle_cast({:send_to_receiver, event}, %__MODULE__{receiver: receiver} = live_socket) do
    if receiver do
      send(receiver, {event, build_payload(live_socket, event)})
    end

    {:noreply, live_socket}
  end

  defp is_phx_view?(el),
    do: Floki.attribute(el, @phx_session) != []

  defp join_root_views(live_socket, document) do
    Floki.find(document, "[#{@phx_session}]:not([#{@phx_parent_id}])")
    |> Enum.reduce(live_socket, fn(root_el, live_socket) ->
      if !get_root_by_id(live_socket.roots, Floki.attribute(root_el, "id")) do
        {:ok, view, live_socket} = new_root_view(live_socket, el: root_el, live_socket: live_socket)

        view = if DOM.is_phx_sticky?(root_el),
          do: %View{view | href: live_socket.href},
          else: view

        {:ok, view, live_socket} = View.join(view, live_socket)

        if Floki.attribute(root_el, @phx_main) != [],
          do: %__MODULE__{live_socket | main_name: view.name},
          else: live_socket
      else
        live_socket
      end
    end)
  end

  def new_root_view(live_socket, opts) do
    {:ok, view, live_socket} = new_view(live_socket, opts)

    live_socket = %__MODULE__{live_socket |
      roots: Map.put(live_socket.roots, view.id, view.name)
    }

    {:ok, view, live_socket}
  end

  def assign(%__MODULE__{name: name}, assigns) do
    GenServer.call(name, {:assign, assigns})
  end

  def new_view(%__MODULE__{refs: refs} = live_socket, opts) do
    opts = Keyword.merge(opts, [{Crane.Object.key_from_module(__MODULE__), live_socket}])

    with {:ok, view} <- View.new(opts),
      refs <- Crane.Utils.monitor(view, refs) do
        live_socket = %__MODULE__{live_socket | refs: refs}
        Crane.Utils.broadcast(Crane, {:new_view, view})

        {:ok, view, live_socket}
    else
      error -> {:error, error, live_socket}
    end
  end

  def join_dead_view(live_socket, %{body: body, document: document}) do
    if (body && !is_phx_view?(body) && !is_phx_view?(document)) do
      {:ok, view, live_socket} = new_root_view(live_socket,
        el: body,
        href: live_socket.href,
        is_dead: true
      )

      :ok = View.exec_new_mounted(view)

      if !live_socket.main_name,
        do: %__MODULE__{live_socket | main_name: view.name},
        else: live_socket
    else
      live_socket
    end
  end

  defp reset_reload_status(%Window{browser_name: browser_name} = window) do
    {:ok, browser} = Browser.get(browser_name)
    delete_cookie(browser, window.location.href, @phx_reload_status)
  end

  defp delete_cookie(%Browser{cookie_jar: cookie_jar} = browser, href, name) do
    request_url = URI.parse(href)
    {:ok, cookie} = HttpCookie.from_cookie_string("#{name}=; max-age=-1; path=/", request_url)
    cookie_jar = HttpCookie.Jar.put_cookie(cookie_jar, cookie)
    Browser.update_cookie_jar(browser, cookie_jar)
  end

  defp get_root_by_id(%{}, _id),
    do: false
  defp get_root_by_id(roots, []),
    do: false
  defp get_root_by_id(roots, [id]),
    do: get_root_by_id(roots, id)

  defp get_root_by_id(roots, id) when is_binary(id),
    do: Map.has_key?(roots, id)

  def new(%Window{name: window_name} = window, url, params \\ %{}) do
    {receiver, params} = Map.pop(params, :receiver)
    {:ok, pid} = start_link(
      window_name: window_name,
      url: url,
      params: params,
      receiver: receiver,
      headers: Window.headers(window)
    )

    GenServer.call(pid, :get)
  end

  def time(%__MODULE__{} = live_socket, name, func) do
    if is_profile_enabled?(live_socket) do
      # TODO: add profiling
      func.()
    else
      func.()
    end
  end

  defp is_profile_enabled?(%__MODULE__{} = live_socket),
    do: !!Map.get(live_socket.session_storage, @phx_lv_profile)

  def attach_receiver(%__MODULE__{name: name}, receiver),
    do: GenServer.call(name, {:attach_receiver, receiver})

  def send_to_receiver(name, event) when is_atom(name),
    do: send_to_receiver(%__MODULE__{name: name}, event)
  def send_to_receiver(%__MODULE__{name: name}, event),
    do: GenServer.cast(name, {:send_to_receiver, event})

  defp build_payload(%__MODULE__{} = live_socket, :view_tree) do
    {:ok, window} = Window.get(live_socket.window_name)
    window.view_trees.container
  end

  def get_binding_prefix(%__MODULE__{binding_prefix: binding_prefix}),
    do: binding_prefix
  def binding(%__MODULE__{} = live_socket, kind),
    do: "#{get_binding_prefix(live_socket)}#{kind}"

  def has_pending_link?(%__MODULE__{pending_link: pending_link} = live_socket),
    do: !!pending_link

  def request_dom_update(%__MODULE__{transitions: transitions} = live_socket, callback) do
    transitions = TransitionSet.after(transitions, callback)

    %__MODULE__{live_socket |
      transitions: transitions
    }
  end

  def transition(%__MODULE__{transitions: transitions} = live_socket, time, on_start, on_done \\ fn() -> nil end) do
    transitions = TransitionSet.add_transition(transitions, time, on_start, on_done)

    %__MODULE__{live_socket |
      transitions: transitions
    }
  end

  def history_redirect(%__MODULE__{} = live_socket,  event, href, link_state, flash, target_el \\ nil) do
    click_loading = target_el and event.is_trusted? and event.type != :popstate
    {:ok, window} = Window.get(live_socket.window_name)

    if !is_connected?(live_socket) || View.is_main?(live_socket.main_name) do
      Browser.redirect(href, flash)
    else
      href = case URI.parse(href) do
        %URI{scheme: nil, host: nil} = uri ->
          "#{window.location.protocol}//#{window.location.host}#{href}"
        _other -> href
      end

      scroll = 0

      # with_page_loading(live_socket, %{to: href, kind: :redirect}, fn(done) ->
      #   replace_main(live_socket, href, flash, fn(link_ref) ->
      #     if link_ref == live_socket.link_ref do
      #       # TODO store history position
      #       # current_history_position = live_socket.current_history_position + 1
      #       window = Browser.update_current_state(window, fn(state) -> 
      #         Map.put(state, back_type: :redirect)
      #       end)
      #
      #       # Browser.push_state(window, link_state, %{
      #       #   type: :redirect,
      #       #   id: 
      #       # })
      #     end
      #
      #   end)
      # end)
    end
  end

  def is_connected?(%__MODULE__{socket: socket}),
    do: Slipstream.Socket.connected?(socket)
end
