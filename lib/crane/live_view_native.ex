defmodule Crane.LiveViewNative do
  alias Crane.Protos.Browser.Response

  def init(_) do
    []
  end

  def call(request, stream, next, _options) do
    case next.(request, stream) do
      {:ok, stream, %Response{body: body} = response} ->
        {:ok, view_tree} = LiveViewNative.Template.Parser.parse_document(body)

        stylesheets = Floki.find(view_tree, "Style") |> Floki.attribute("url")

        view_trees = %{
          "main" => to_proto(view_tree, "[data-phx-main] > *"),
          "disconnected" => lifecycle_template(view_tree, "disconnected"),
          "reconnecting" => lifecycle_template(view_tree, "reconnecting"),
          "error" => lifecycle_template(view_tree, "error")
        }

        {
          :ok,
          stream,
          %Response{response | view_trees: view_trees, stylesheets: stylesheets}
        }
      other ->
        other
    end
  end

  defp to_proto(view_tree, selector) do
    view_tree
    |> Floki.find(selector)
    |> Crane.Protos.from_doc()
  end

  defp lifecycle_template(view_tree, type) do
    to_proto(view_tree, ~s'head [template="#{type}"')
  end
end
