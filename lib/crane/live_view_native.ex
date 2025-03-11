defmodule Crane.LiveViewNative do
  alias Crane.Protos.Browser.{Request, Response}

  def init(_) do
    []
  end

  def call(%Request{} = request, stream, next, _options) do
    case next.(request, stream) do
      {:ok, stream, response} ->
        {:ok, view_tree} = LiveViewNative.Template.Parser.parse_document(response.body)
        view_tree = Floki.find(view_tree, "[data-phx-main] > *")
        {:ok, stream, %Response{response | view_tree: Crane.Protos.from_doc(view_tree)}}
      error ->
        error
    end
  end

  def call(request, stream, next, _options) do
    next.(request, stream)
  end
end
