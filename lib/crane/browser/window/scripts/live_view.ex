defmodule LiveView do
  alias Crane.Browser.Window
  alias LiveView.LiveSocket

  def call(%Window{} = window, opts) do
    # {receiver, _opts} = Keyword.pop(opts, :receiver)
    # case GenDOM.Document.query_selector(window.view_trees.document, "csrf-token") do
    #   nil -> :none
    #   element ->
    #     csrf_token = Map.get(element.attributes, "value")
    #     {:ok, live_socket} = LiveSocket.new(window, "/live", %{"_csrf_token" => csrf_token, "_format" => "swiftui", receiver: receiver})
    #     Window.monitor(window, live_socket)
    # end
  end
end
