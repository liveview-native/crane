# Cribbed from Slipstream
defmodule LiveView.LiveSocket.Callback do
  @moduledoc false

  alias LiveView.LiveSocket
  alias Slipstream.{Events, Socket, TelemetryHelper}

  @known_callbacks [{:__no_op__, 2} | Slipstream.behaviour_info(:callbacks)]

  def dispatch(module, event, %LiveSocket{socket: socket} = live_socket) do
    socket = Socket.apply_event(socket, event)
    {function, args} = determine_callback(event, %LiveSocket{live_socket | socket: socket})

    dispatch_module =
      if function_exported?(module, function, length(args)) do
        module
      else
        Slipstream.Default
      end

    wrap_dispatch(module, function, args, fn ->
      apply(dispatch_module, function, args)
      |> handle_callback_return()
    end)
  end

  defp wrap_dispatch(module, function, args, func) do
    %LiveSocket{socket: socket} = List.last(args)

    metadata = %{
      client: module,
      callback: function,
      arguments: args,
      socket: %Slipstream.Socket{socket | metadata: %{}},
      start_time: DateTime.utc_now()
    }

    return_value =
      :telemetry.span(
        [:slipstream, :client, function],
        metadata,
        fn ->
          return = func.()

          metadata =
            Map.merge(metadata, %{
              return: return
            })

          {return, metadata}
        end
      )

    return_value
  end

  defp handle_callback_return({:ok, %LiveSocket{} = live_socket}), do: {:noreply, live_socket}

  defp handle_callback_return({:ok, %LiveSocket{} = live_socket, others}),
    do: {:noreply, live_socket, others}

  defp handle_callback_return({:noreply, %LiveSocket{}} = return), do: return

  defp handle_callback_return({:noreply, %LiveSocket{}, _others} = return),
    do: return

  defp handle_callback_return({:stop, _reason, %LiveSocket{}} = return), do: return

  defmacrop callback(name, args) do
    arity = length(args) + 1

    unless {name, arity} in @known_callbacks do
      raise CompileError,
        file: __CALLER__.file,
        line: __CALLER__.line,
        description: "cannot wrap unknown callback #{name}/#{arity}"
    end

    quote do
      {unquote(name), unquote(args)}
    end
  end

  def determine_callback(event, live_socket) do
    {name, args} = _determine_callback(event)

    # inject socket as last arg, always
    {name, args ++ [live_socket]}
  end

  defp _determine_callback(%Events.ChannelConnected{}) do
    callback :handle_connect, []
  end

  defp _determine_callback(%Events.TopicJoinSucceeded{} = event) do
    callback :handle_join, [event.topic, event.response]
  end

  defp _determine_callback(%Events.TopicJoinFailed{} = event) do
    callback :handle_topic_close, [
      event.topic,
      Events.TopicJoinFailed.to_reason(event)
    ]
  end

  defp _determine_callback(%Events.TopicJoinClosed{} = event) do
    callback :handle_topic_close, [event.topic, event.reason]
  end

  defp _determine_callback(%Events.TopicLeft{} = event) do
    callback :handle_leave, [event.topic]
  end

  defp _determine_callback(%Events.TopicLeaveAccepted{} = event) do
    callback :__no_op__, [event]
  end

  defp _determine_callback(%Events.ReplyReceived{} = event) do
    callback :handle_reply, [event.ref, event.reply]
  end

  defp _determine_callback(%Events.MessageReceived{} = event) do
    callback :handle_message, [event.topic, event.event, event.payload]
  end

  defp _determine_callback(%Events.ChannelConnectFailed{} = event) do
    callback :handle_disconnect, [{:error, event.reason}]
  end

  defp _determine_callback(%Events.ChannelClosed{} = event) do
    callback :handle_disconnect, [event.reason]
  end

  defp _determine_callback(event) do
    callback :handle_info, [event]
  end
end
