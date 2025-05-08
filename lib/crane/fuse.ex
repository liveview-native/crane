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
      root: root_template(document),
      main: main_template(document),
      loading: lifecycle_template(document, "loading"),
      disconnected: lifecycle_template(document, "disconnected"),
      reconnecting: lifecycle_template(document, "reconnecting"),
      error: lifecycle_template(document, "error")
    }
  end

  defp has_attribute?(el, attribute) do
    Floki.attribute(el, attribute) |> List.first()
  end

  defp main_template(view_tree),
    do: Floki.find(view_tree, "data-phx-main")

  defp root_template(view_tree) do
    Floki.find(view_tree, "body > *")
    |> Floki.traverse_and_update(fn 
      {tag_name, attributes, children} = element ->
        if has_attribute?(element, "data-phx-main") do
          {tag_name, attributes, []}
        else
          element
        end
    end)
  end

  defp lifecycle_template(view_tree, type) do
    Floki.find(view_tree, ~s'head [template="#{type}"')
  end
end
