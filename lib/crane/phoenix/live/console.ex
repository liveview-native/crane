defmodule Crane.Phoenix.Live.Console do
  use Phoenix.LiveView

  @topic "logger"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PhoenixPlayground.PubSub, @topic)
    end

    socket =
      socket
      |> assign(temporary_assigns: [form: nil])
      |> stream(:posts, [])
      |> assign(:form, to_form(%{"content" => ""}))

    {:ok, socket}
  end
end
