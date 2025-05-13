defmodule Crane.Fuse do
  alias Req.Response

  import LiveView.DOM

  def run_middleware(:visit, %Response{status: 200, body: body}) do
    {:ok, document} = LiveViewNative.Template.Parser.parse_document(body,
      strip_comments: true,
      text_as_node: true,
      inject_identity: true)

    stylesheets = Floki.find(document, "Style") |> Floki.attribute("url")

    {_document, view_trees} = find_view_trees({document, %{}})

    %{status: 200,
      view_trees: view_trees,
      stylesheets: stylesheets}
  end

  def run_middleware(:visit, %Response{status: status, body: body}) do
    %{
      status: status, body: body
    }
  end

  def find_view_trees({document, view_trees}) do
    view_trees =
      Map.merge(view_trees, %{
        document: document,
        body: Floki.find(document, "body > *"),
        root: root_template(document),
        container: Floki.find(document, "[data-phx-main]"),
        loading: lifecycle_template(document, "loading"),
        disconnected: lifecycle_template(document, "disconnected"),
        reconnecting: lifecycle_template(document, "reconnecting"),
        error: lifecycle_template(document, "error")
      })

    {document, view_trees}
  end

  def root_template(view_tree) do
    view_tree
    |> Floki.find("body > *")
    |> Floki.traverse_and_update(fn 
      {tag_name, attributes, children} = element ->
        if has_attribute?(element, "data-phx-main") do
          {tag_name, attributes, []}
        else
          element
        end
    end)
  end

  def lifecycle_template(view_tree, type) do
    Floki.find(view_tree, ~s'head [template="#{type}"')
  end
end
