defmodule LiveView.MorphDOM do
  @element_node 1
  @text_node 3

  def morph(from_node, to_node, opts \\ []) do
    morph(from_node, to_node, opts, %{})
  end

  defp morph(from_node, to_node, opts, keyed_nodes) do
    get_node_key = Keyword.get(opts, :get_node_key, fn node ->
      if node.id == "" do
        nil
      else
        node.id
      end
    end)
    skip_from_children = Keyword.get(opts, :skip_from_children, fn _node -> false end)
    add_child = Keyword.get(opts, :add_child, &GenDOM.Node.append_child/2)
    on_before_node_added = Keyword.get(opts, :on_before_node_added, fn node -> node end)
    on_node_added = Keyword.get(opts, :on_node_added, fn node -> node end)
    on_before_node_discarded = Keyword.get(opts, :on_before_node_discarded, fn _node -> true end)
    on_node_discarded = Keyword.get(opts, :on_node_discarded, fn node -> node end)
    on_before_element_updated = Keyword.get(opts, :on_before_element_updated, fn from_element, _to_element -> from_element end)
    on_element_updated = Keyword.get(opts, :on_element_updated, fn element -> element end)
    children_only = Keyword.get(opts, :children_only)

    from_node = GenDOM.Node.get(from_node)
    to_node = GenDOM.Node.get(to_node)

    zipped_children = :lists.zip(
      Enum.map(from_node.child_nodes, &GenDOM.Node.get/1),
      Enum.map(to_node.child_nodes, &GenDOM.Node.get/1),
      {:pad, {nil, nil}}
    )
    Enum.reduce(zipped_children, keyed_nodes, fn
      {from_child, nil}, acc -> # element removed
        on_before_node_discarded.(from_child)
        GenDOM.Node.remove_child(from_node, from_child)
        on_node_discarded.(from_child)
        if key = get_node_key.(from_child) do
          # keep track of keyed nodes, we might match them later
          Map.put(acc, key, from_child)
        else
          acc
        end
      {nil, to_child}, acc -> # element added
        on_before_node_added.(to_child)
        add_child.(from_node, to_child)
        on_node_added.(to_child)
        acc
      {%{ node_type: @element_node } = from_child, %{ node_type: @element_node } = to_child}, acc -> # element changed
        if existing_child = Map.get(acc, get_node_key.(to_child)) do

        end
        on_before_element_updated.(from_child, to_child)
        Enum.each([:tag_name, :attributes, :class_list], fn prop ->
          new_value = Map.get(to_child, prop)
          if Map.get(from_child, prop) != new_value do
            GenDOM.Node.put(from_child, prop, new_value)
          end
        end)
        on_element_updated.(from_child)
        morph(
          from_child,
          to_child,
          opts,
          if key = get_node_key.(from_child) do
            Map.delete(acc, key)
          else
            acc
          end
        )
      {
        %{ node_type: @text_node, whole_text: from_whole_text } = from_child,
        %{ node_type: @text_node, whole_text: to_whole_text } = _to_child
      }, acc when from_whole_text != to_whole_text -> # text changed
        GenDOM.Node.put(from_child, :whole_text, to_whole_text)
        acc
      {%{ node_type: from_node_type } = from_child, %{ node_type: to_node_type } = to_child}, acc when from_node_type != to_node_type -> # text -> element or element -> text
        on_before_node_discarded.(from_child)
        on_before_node_added.(to_child)
        # replace the child
        GenDOM.Node.replace_child(from_node, to_child, from_child)
        on_node_discarded.(from_child)
        on_node_added.(to_child)
        if key = get_node_key.(from_child) do
          Map.put(acc, key, from_child)
        else
          acc
        end
    end)
  end

  # def morphdom(from_node, to_node, opts \\ []) do
  #   get_node_key = Keyword.get(opts, :get_node_key, fn _node -> nil end)
  #   skip_from_children = Keyword.get(opts, :skip_from_children, fn _node -> false end)
  #   add_child = Keyword.get(opts, :add_child, &GenDOM.Node.append_child/2)
  #   on_before_node_added = Keyword.get(opts, :on_before_node_added, fn node -> node end)
  #   on_node_added = Keyword.get(opts, :on_node_added, fn node -> node end)
  #   on_before_node_discarded = Keyword.get(opts, :on_before_node_discarded, fn _node -> true end)
  #   on_node_discarded = Keyword.get(opts, :on_node_discarded, fn node -> node end)
  #   on_before_element_updated = Keyword.get(opts, :on_before_element_updated, fn from_element, to_element -> from_element end)
  #   on_element_updated = Keyword.get(opts, :on_element_updated, fn element -> element end)
  #   children_only = Keyword.get(opts, :children_only)

  #   from_node = GenDOM.Node.get(from_node)
  #   morphed_node = from_node
  #   to_node = GenDOM.Node.get(to_node)

  #   if not Keyword.get(opts, :children_only) do
  #     # handle two dom nodes that are not compatible.
  #     # (e.g. <div> --> <span> or <div> --> TEXT)
  #     raise "todo"
  #   end

  #   morphed_node = if GenDOM.Node.is_same_node?(to_node, morphed_node) do
  #     Keyword.get(opts, :on_node_discarded).(from_node)
  #     morphed_node
  #   else
  #     {morphed_node, keyed_removal_list, from_nodes_lookup} = morph_element(morphed_node, to_node, [], %{}, opts)

  #     # We now need to loop over any keyed nodes that might need to be
  #     # removed. We only do the removal if we know that the keyed node
  #     # never found a match. When a keyed node is matched up we remove
  #     # it out of fromNodesLookup and we use fromNodesLookup to determine
  #     # if a keyed node has been matched up or not
  #     for key <- keyed_removal_list do
  #       element = Map.get(from_nodes_lookup, key)
  #       remove_node(element, element.parent, false, opts)
  #     end

  #     if children_only and not GenDOM.Node.is_same_node?(morphed_node, from_node) and from_node.parent_node do
  #       # If we had to swap out the from node with a new node because the old
  #       # node was not compatible with the target node then we need to
  #       # replace the old DOM node in the original DOM tree. This is only
  #       # possible if the original DOM node was part of a DOM tree which
  #       # we know is the case if it has a parent node.
  #       raise "todo"
  #     else
  #       morphed_node
  #     end
  #   end
  # end

  # # Removes a DOM node out of the original DOM.
  # defp remove_node(node, parent, skip_keyed_nodes, opts) do
  #   if not Keyword.get(opts, :on_before_node_discarded).(node) do
  #     node
  #   else
  #     if parent != nil do
  #       GenDOM.Node.remove_child(parent, node)
  #     end

  #     Keyword.get(opts, :on_node_discarded).(node)
  #     walk_discarded_child_nodes(node, skip_keyed_nodes)
  #   end
  # end

  # # walks the children of the node and returns a list of keyed nodes.
  # defp walk_discarded_child_nodes(node, skip_keyed_nodes, opts) when node.node_type == @element_node do
  #   node = GenDOM.Node.get(node)
  #   if node.first_child do
  #     walk_discarded_nodes(node.first_child, skip_keyed_nodes, opts)
  #   else
  #     []
  #   end
  # end

  # defp walk_discarded_nodes(node, skip_keyed_nodes, keyed_removal, opts) when node.node_type == @element_node do
  #   key = get_node_key(opts, node)
  #   keyed_removal = if skip_keyed_nodes and key do
  #     # If we are skipping keyed nodes then we add the key
  #     # to a list so that it can be handled at the very end.
  #     [key | keyed_removal]
  #   else
  #     # Only report the node as discarded if it is not keyed. We do this because
  #     # at the end we loop through all keyed elements that were unmatched
  #     # and then discard them in one final pass.
  #     opts.on_node_discarded(node)
  #     walk_discarded_child_nodes(node, skip_keyed_nodes, opts)
  #   end
  #   walk_discarded_nodes(GenDOM.Node.get(node).next_sibling, skip_keyed_nodes, opts)
  # end

  # defp walk_discarded_nodes(_node, _skip_keyed_nodes, keyed_removal, _opts) do
  #   keyed_removal
  # end

  # defp morph_element(from_node, to_node, keyed_removal_list, from_nodes_lookup, opts) do
  #   to_key = opts.get_node_key(to_node)
  #   from_nodes_lookup = if to_key do
  #     Map.delete(from_nodes_lookup, to_key)
  #   else
  #     from_nodes_lookup
  #   end

  #   if not opts.children_only do
  #     raise "todo"
  #   end

  #   morph_children(from_node, to_node, keyed_removal_list, from_nodes_lookup, opts)
  # end

  # defp morph_children(from_node, to_node, keyed_removal_list, from_nodes_lookup, opts) do
  #   skip_from = opts.skip_from_children(from_node, to_node)

  #   walk_to_children = fn to_node_child ->
  #     to_next_sibling = to_node_child.next_sibling
  #     to_node_key = opts.get_node_key(to_node_child)

  #     # walk the from_node children all the way through
  #     # looks for one that matches the to_node_child
  #     for from_child <- from_node.child_nodes do
  #       if GenDOM.Node.is_same_node?(to_node_child, from_child) do

  #       end
  #     end
  #   end

  #   walk_to_children(to_node.first_child)

  #   {morphed_node, keyed_removal_list, from_nodes_lookup}
  # end

  # defp compare_node_names(from_node, to_node) do
  #   raise "todo"
  # end

  # defp move_children(from_node, to_node) do
  #   raise "todo"
  #   to_node
  # end

  # defp get_node_key(opts, node) do
  #   Keyword.get(opts, :get_node_key, fn node ->
  #     GenDOM.Element.get_attribute(node, "id")
  #   end).(node)
  # end
end
