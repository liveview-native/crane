defmodule Crane.Protos do
  alias Crane.Protos.Browser.Node
  alias Crane.Protos.Browser.Node.Attribute

  def from_doc(view_tree) when is_list(view_tree) do
    %Node{
      type: "root",
      children: parse_child_nodes(view_tree)
    }
  end

  defp to_node(text) when is_binary(text) do
    %Node{
      type: "text",
      text_content: text
    }
  end

  defp to_node({tag_name, attributes, children}) do
    %Node{
      type: "element",
      tag_name: tag_name,
      attributes: Enum.map(attributes, &(to_attribute(&1))),
      children: parse_child_nodes(children)
    }
  end

  defp parse_child_nodes(nodes) when is_list(nodes) do
    Enum.reduce(nodes, [], fn
      [comment: _comment], acc -> acc
      [:comment, _comment], acc -> acc
      {:comment, __comment}, acc -> acc
      node, acc -> [to_node(node) | acc]
    end)
    |> Enum.reverse()
  end

  defp to_attribute({name, value}) do
    %Attribute{
      name: name,
      value: value
    }
  end
end
