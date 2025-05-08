defmodule Crane.Fuse do
  alias Req.Response

  def run_middleware(:visit, %Response{status: 200, body: body}) do
    {:ok, document} = LiveViewNative.Template.Parser.parse_document(body,
      strip_comments: true,
      text_as_node: true,
      inject_identity: true)

    stylesheets = Floki.find(document, "Style") |> Floki.attribute("url")

   %{
      status: 200,
      view_trees: find_view_trees(document),
      stylesheets: stylesheets
    }
  end

  def run_middleware(:visit, %Response{status: status, body: body}) do
    %{
      status: status, body: body
    }
  end

  def find_view_trees(document) do
    %{
      document: document,
      body: Floki.find(document, "body > *"),
      loading: lifecycle_template(document, "loading"),
      disconnected: lifecycle_template(document, "disconnected"),
      reconnecting: lifecycle_template(document, "reconnecting"),
      error: lifecycle_template(document, "error")
    }
  end

  def run_middleware(:visir, _response),
    do: %{view_trees: [], stylesheets: []}

  defp lifecycle_template(view_tree, type) do
    Floki.find(view_tree, ~s'head [template="#{type}"')
  end
end
