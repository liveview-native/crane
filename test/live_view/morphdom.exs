defmodule LiveView.RenderedTest do
  use ExUnit.Case, async: true

  describe "morph" do
    test "text morph" do
      from_document = GenDOM.Parser.parse_from_string("<Text>Hello, world!</Text>", nil, [])
      to_document = GenDOM.Parser.parse_from_string("<Text>Goodbye, world!</Text>", nil, [])

      from_text = from_document.child_nodes
        |> hd()
        |> GenDOM.Node.get()
        |> Map.get(:child_nodes)
        |> hd()
      assert(GenDOM.Node.get(from_text).whole_text == "Hello, world!")

      LiveView.MorphDOM.morph(from_document, to_document)

      assert(GenDOM.Node.get(from_text).whole_text == "Goodbye, world!")
    end

    test "element attribute morph" do
      from_document = GenDOM.Parser.parse_from_string("<Spacer />", nil, [])
      to_document = GenDOM.Parser.parse_from_string("<Spacer class=\"test-class\" />", nil, [])

      from_element = hd(from_document.child_nodes)
      assert(GenDOM.Node.get(from_element).class_list == [])

      LiveView.MorphDOM.morph(from_document, to_document)

      assert(GenDOM.Node.get(from_element).class_list == ["test-class"])
    end

    test "add child" do
      from_document = GenDOM.Parser.parse_from_string("<VStack><A /></VStack>", nil, [])
      to_document = GenDOM.Parser.parse_from_string("<VStack><A /><B /></VStack>", nil, [])

      from_element = hd(from_document.child_nodes)
      assert(length(GenDOM.Node.get(from_element).child_nodes) == 1)

      LiveView.MorphDOM.morph(from_document, to_document)

      assert(length(GenDOM.Node.get(from_element).child_nodes) == 2)
    end

    test "remove child" do
      from_document = GenDOM.Parser.parse_from_string("<VStack><A /><B /></VStack>", nil, [])
      to_document = GenDOM.Parser.parse_from_string("<VStack><A /></VStack>", nil, [])

      from_element = hd(from_document.child_nodes)
      assert(length(GenDOM.Node.get(from_element).child_nodes) == 2)

      LiveView.MorphDOM.morph(from_document, to_document)

      assert(length(GenDOM.Node.get(from_element).child_nodes) == 1)
    end

    test "swap child" do
      # FIXME: Currently, the morph doesn't support swapping elements that are
      # the same. The original morphdom doesn't use a zip of child nodes, but
      # walks the to_node and for each sibling it searches the from_node for a
      # match.
      from_document = GenDOM.Parser.parse_from_string("<VStack><A id=\"a\" /><B id=\"b\" /></VStack>", nil, [])
      to_document = GenDOM.Parser.parse_from_string("<VStack><B id=\"b\" /><A id=\"a\" /></VStack>", nil, [])

      child_nodes = from_document.child_nodes
        |> hd()
        |> GenDOM.Node.get()
        |> Map.get(:child_nodes)
      dbg child_nodes

      LiveView.MorphDOM.morph(from_document, to_document)

      assert(child_nodes == Enum.reverse(child_nodes))
    end
  end
end
