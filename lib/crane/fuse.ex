defmodule Crane.Fuse do
  alias Req.Response

  def run_middleware(:visit, %Response{status: 200, body: body}) do
    {:ok, view_tree} = LiveViewNative.Template.Parser.parse_document(body)

    stylesheets = Floki.find(view_tree, "Style") |> Floki.attribute("url")

    view_trees = %{
      "body" => Floki.find(view_tree, "body > *"),
      "disconnected" => lifecycle_template(view_tree, "disconnected"),
      "reconnecting" => lifecycle_template(view_tree, "reconnecting"),
      "error" => lifecycle_template(view_tree, "error")
    }

    %{
      view_trees: view_trees,
      stylesheets: stylesheets
    }
  end

  def run_middleware(:visir, _response),
    do: %{view_trees: [], stylesheets: []}

  defp lifecycle_template(view_tree, type) do
    Floki.find(view_tree, ~s'head [template="#{type}"')
  end
end
