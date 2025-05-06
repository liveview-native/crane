# defmodule LiveView.Channel do
#   use GenServer
#
#   def start_channel(state, view, ref, url, redirect_url) do
#     from = {self(), ref}
#
#     {:ok, socket} = LiveSocket.assign(state.socket, fn(socket) ->
#       topics = socket.assigns.topics || %{}
#       topics = Map.put(topics, view.topic, from)
#
#       %LiveSocket{live_socket |
#         socket: SlipStream.Socket.assign(socket, topics: topics)
#       }
#     end)
#
#     socket = Slipstream.join(socket, view.topic)
#     # socket = %Phoenix.Socket{
#     #   transport_pid: self(),
#     #   serializer: __MODULE__,
#     #   channel: view.module,
#     #   endpoint: view.endpoint,
#     #   private: %{connect_info: Map.put_new(view.connect_info, :session, state.session)},
#     #   topic: view.topic,
#     #   join_ref: state.join_ref
#     # }
#
#     params = %{
#       "session" => view.session_token,
#       "static" => view.static_token,
#       "params" => Map.put(view.connect_params, "_mounts", 0),
#       "caller" => state.caller,
#     }
#
#     params = put_non_nil(params, "url", url)
#     params = put_non_nil(params, "redirect", redirect_url)
#
#     from = {self(), ref}
#
#     spec = %{
#       id: make_ref(),
#       start: {__MODULE__, :start_link, [{view.endpoint, from}]},
#       restart: :temporary
#     }
#
#     with {:ok, pid} <- Supervisor.start_child(state.test_supervisor, spec) do
#       send(pid, {Phoenix.Channel, params, from, socket})
#       {:ok, pid}
#     end
#   end
# end
