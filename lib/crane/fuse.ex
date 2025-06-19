defmodule Crane.Fuse do
  alias Req.Response

  def run_middleware(:visit, %Response{status: 200, body: body}) do
    document = GenDOM.Parser.parse_from_string(body, nil, [])
    # {:ok, document} = LiveViewNative.Template.Parser.parse_document(body,
    #   strip_comments: true,
    #   text_as_node: true,
    #   inject_identity: true)

    stylesheets =
      GenDOM.Document.query_selector_all(document, "Style")
      |> Enum.map(&(Map.get(&1.attributes, "url")))

    view_trees = find_view_trees({document, %{}})

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
        body: encode(GenDOM.Document.query_selector_all(document, "body > *")),
        loading: lifecycle_template(document, "loading"),
        disconnected: lifecycle_template(document, "disconnected"),
        reconnecting: lifecycle_template(document, "reconnecting"),
        error: lifecycle_template(document, "error")
      })

    view_trees
  end

  def lifecycle_template(view_tree, type) do
    GenDOM.Document.query_selector_all(view_tree, ~s'head [template="#{type}"]') |> encode()
  end

  defp encode(dom) when is_list(dom) do
    Enum.map(dom, &apply(&1.__struct__, :encode, [&1]))
  end
end
