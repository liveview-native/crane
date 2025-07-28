defmodule Crane.Fuse do
  alias Req.Response

  def run_middleware(:visit, %Response{status: 200, body: body} = response) do
    document_pid = GenDOM.Parser.parse_from_string(body, "application/swiftui", [])
    # {:ok, document} = LiveViewNative.Template.Parser.parse_document(body,
    #   strip_comments: true,
    #   text_as_node: true,
    #   inject_identity: true)

    stylesheets =
      GenDOM.Document.query_selector_all(document_pid, "Style")
      |> Enum.map(fn(pid) ->
        element = GenDOM.Element.get(pid)
        Map.get(element.attributes, "url")
      end)

    view_trees = find_view_trees({document_pid, %{}})

    %{status: 200,
      view_trees: view_trees,
      stylesheets: stylesheets}
  end

  def run_middleware(:visit, %Response{status: status, body: body} = response) do
    %{
      status: status, body: body
    }
  end

  def find_view_trees({document_pid, view_trees}) do
    view_trees =
      Map.merge(view_trees, %{
        document: document_pid,
        body: encode(GenDOM.Document.query_selector_all(document_pid, "body > *")),
        loading: lifecycle_template(document_pid, "loading"),
        disconnected: lifecycle_template(document_pid, "disconnected"),
        reconnecting: lifecycle_template(document_pid, "reconnecting"),
        error: lifecycle_template(document_pid, "error")
      })

    view_trees
  end

  def lifecycle_template(view_tree, type) do
    GenDOM.Document.query_selector_all(view_tree, ~s'head [template="#{type}"]') |> encode()
  end

  defp encode(dom) when is_list(dom) do
    Enum.map(dom, &apply(GenDOM.Node, :encode, [&1]))
  end
end
