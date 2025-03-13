defmodule Crane.Protos do
  alias Crane.Protos.Browser.{
    Document,
    Document.Node,
    Document.Node.Attribute
  }

  def from_doc(nodes) do
    {nodes, _state} = parse_child_nodes(nodes, %{id: 1})

    %Document{
      nodes: nodes
    }
  end

  defp to_node(text, state) when is_binary(text) do
    node = %Node{
      type: "text",
      id: state.id,
      text_content: text
    }

    {node, %{state | id: state.id + 1}}
  end

  defp to_node({tag_name, attributes, children}, state) do
    node = %Node{
      type: "element",
      tag_name: tag_name,
      attributes: Enum.map(attributes, &(to_attribute(&1))),
      id: state.id
    }

    state = %{state | id: state.id + 1}

    {children, state} = parse_child_nodes(children, state)

    {%Node{node | children: children}, state}
  end

  defp parse_child_nodes(nodes, state) when is_list(nodes) do
    {nodes, state} = Enum.reduce(nodes, {[], state}, fn
      [comment: _comment], acc -> acc
      [:comment, _comment], acc -> acc
      {:comment, __comment}, acc -> acc
      node, {nodes, state} ->
        {node, state} = to_node(node, state)
        {[node | nodes], state}
    end)

    {Enum.reverse(nodes), state}
  end

  defp to_attribute({name, value}) do
    %Attribute{
      name: name,
      value: value
    }
  end
end
