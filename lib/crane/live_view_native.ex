defmodule Crane.LiveViewNative do
  alias Crane.Protos.Browser.{Request, Response}

  def init(_) do
    []
  end

  def call(%Request{} = request, stream, next, _options) do
    case next.(request, stream) do
      {:ok, stream, response} ->
        {:ok, view_tree} = LiveViewNative.Template.Parser.parse_document(response.body)
        stylesheets = Floki.find(view_tree, "Style") |> Floki.attribute("url")

        view_trees = %{
          "main" => Floki.find(view_tree, "[data-phx-main] > *") |> Crane.Protos.from_doc()
        }

        {:ok, stream, %Response{
          response | view_trees: view_trees, stylesheets: stylesheets
        }}
      error ->
        error
    end
  end

  def call(request, stream, next, _options) do
    next.(request, stream)
  end
end
