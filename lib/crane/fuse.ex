defmodule Crane.Fuse do
  alias Req.Response

  def run_middleware(type, response, opts \\ [])

  def run_middleware(:visit, %Response{status: 200, body: body} = response, opts) do
    document = GenDOM.Parser.parse_from_string(body, "application/swiftui", [
      receiver: opts[:receiver],
      window: opts[:window],
      event_registry: opts[:event_registry]
    ])

    stylesheets =
      GenDOM.Document.query_selector_all(document, "Style")
      |> Enum.map(fn(pid) ->
        element = GenDOM.Element.get(pid)
        Map.get(element.attributes, "url")
      end)

    view_trees = find_view_trees({document.pid, %{}})

    response = %{status: 200,
      view_trees: view_trees,
      window: document.window,
      event_registry: document.event_registry,
      stylesheets: stylesheets}

    if (receiver_pid = opts[:receiver]) && is_pid(receiver_pid) do
      send(receiver_pid, {:visit, response})
    end

    response
  end

  def run_middleware(:visit, %Response{status: status, body: body} = response, opts) do
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
