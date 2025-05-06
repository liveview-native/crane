defmodule LiveView do
  alias Crane.Browser.Window
  alias LiveView.LiveSocket

  def call(%Window{} = window, receiver \\ nil) do
    [csrf_token] = Floki.attribute(window.view_trees.document, "csrf-token", "value")
    {:ok, live_socket} = LiveSocket.new(window, "/live", %{"_csrf_token" => csrf_token, "_format" => "swiftui"})
    Window.monitor(window, live_socket)
  end
end
