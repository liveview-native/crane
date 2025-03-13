defmodule Crane.ProtosTest do
  use ExUnit.Case

  describe "encoding Floki document trees as Protobuffs" do
    test "will create a node tree with incrementing node ids" do
      document = """
      <Group>
        <Text>Brian</Text>
        <Group>
          <Text>Cardarella</Text>
        </Group>
      </Group>
      """
      |> LiveViewNative.Template.Parser.parse_document!()
      |> Crane.Protos.from_doc()

      assert ensure_ids_unique(document.nodes)
    end
  end

  defp ensure_ids_unique(nodes) do
    ids = collect(nodes, &(&1.id))

    ids == Enum.uniq(ids)
  end

  defp collect(nodes, fun, acc \\ [])

  defp collect([], _fun, acc),
    do: acc
  defp collect([node |  nodes], fun, acc) do
    acc = [fun.(node) | acc]
    collect(node.children, fun) ++ collect(nodes, fun) ++ acc
  end
end
