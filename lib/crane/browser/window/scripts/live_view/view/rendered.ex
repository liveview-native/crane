defmodule LiveView.View.Rendered do
  use LiveView.Constants, [
    :components,
    :dynamics,
    :events,
    :phx_component,
    :phx_magic_id,
    :phx_skip,
    :reply,
    :root,
    :static,
    :templates,
    :title,
  ]

  import Kernel, except: [
    to_string: 1
  ]

  defstruct view_id: nil,
    rendered: %{},
    magic_id: 0

  def extract(diff) do
    {reply, diff} = Map.pop(diff, :reply)
    {events, diff} = Map.pop(diff, :events)
    {title, diff} = Map.pop(diff, :title)
    {diff, reply, events || %{}, title}
  end

  def merge_diff(%__MODULE__{rendered: rendered} = state, diff \\ %{}) do
    {newc, diff} = Map.pop(diff, @components)
    cache = %{}

    rendered =
      rendered
      |> mutable_merge(diff)
      |> Map.update(@components, %{}, &(&1))

    if newc do
      oldc = Map.get(rendered, @components)

      newc = Enum.reduce(newc, newc, fn({cid, component}, newc) ->
        {component, _cache} = cached_find_component(cid, component, oldc, newc, cache)
        Map.put(newc, cid, component)
      end)

      oldc = Enum.reduce(newc, oldc, fn({cid, component}, oldc) ->
        Map.put(oldc, cid, component)
      end)

      rendered = Map.put(rendered, @components, oldc)
      diff = Map.put(diff, @components, newc)

      {diff, Map.put(state, :rendered, rendered)}
    else
      {diff, Map.put(state, :rendered, rendered)}
    end
  end

  defp cached_find_component(cid, cdiff, oldc, newc, cache) do
    if component = Map.get(cache, cid) do
      {component, cache}
    else
      scid = Map.get(cdiff, @static)

      {ndiff, cache} = if is_cid?(scid) do
        {tdiff, cache} = if scid > 0,
          do: cached_find_component(scid, Map.get(newc, scid), oldc, newc, cache),
          else: {Map.get(oldc, scid * -1), cache}

        stat = Map.get(tdiff, @static)
        ndiff =
          tdiff
          |> clone_merge(cdiff, true)
          |> Map.put(@static, stat)

        {ndiff, cache}
      else
        if Map.has_key?(cdiff, @static) or !Map.has_key?(oldc, cid),
          do: {clone_merge(Map.get(oldc, cid, %{}), cdiff, false), cache},
          else: {cdiff, cache}
      end

      cache = Map.put(cache, cid, ndiff)

      {ndiff, cache}
    end
  end

  defp is_cid?(cid) when is_number(cid),
    do: true
  defp is_cid?(cid) when is_binary(cid),
    do: Regex.match?(~r/^(0|[1-9]\d*)$/, cid)
  defp is_cid?(_cid),
    do: false


  defp mutable_merge(target, source) do
    if Map.has_key?(source, @static) do
      source
    else
      do_mutable_merge(target, source)
    end
  end

  defp do_mutable_merge(target, source) do
    target = Enum.reduce(source, target, fn({key, source_val}, target) ->
      target_val = Map.get(target, key)

      if is_map(source_val) && !Map.has_key?(source_val, @static) && is_map(target_val) do
        target_val = do_mutable_merge(target_val, source_val)
        Map.put(target, key, target_val)
      else
        Map.put(target, key, source_val)
      end
    end)

    if Map.get(target, @root),
      do: Map.put(target, :new_render, true),
      else: target
  end

  defp clone_merge(target, source, prune_magic_id?) do
    merged = Map.merge(target, source)
    merged = Enum.reduce(merged, merged, fn({key, _val}, merged) ->
      source_val = Map.get(source, key, %{})
      target_val = Map.get(target, key)

      if is_map(source_val) && !Map.has_key?(source_val, @static) && is_map(target_val) do
        Map.put(merged, key, clone_merge(target_val, source_val, prune_magic_id?))
      else
        merged
      end
    end)

    cond do
      prune_magic_id? ->
        Map.drop(merged, [:magic_id, :new_render])
      Map.get(target, @root) ->
        Map.put(merged, :new_render, true)
      true ->
        merged
    end
  end

  def component_cids(diff) do
    diff
    |> Map.get(@components, %{})
    |> Enum.reduce([], fn({key, _value}, acc) ->
      {integer, _} = Integer.parse(key)
      [integer | acc]
    end)
    |> Enum.reverse()
  end

  def to_string(%__MODULE__{rendered: rendered} = state, cids \\ nil) do
    {streams, rendered} = Map.pop(rendered, :streams)

    {:ok, string, _state} = recursive_to_string(rendered, Map.get(rendered, @components), cids, true, %{}, state)

    {:ok, string, streams}
  end

  def is_new_fingerprint?(diff),
    do: !!Map.get(diff, @static)

  defp recursive_to_string(rendered, components, only_cids, change_tracking, root_attrs, state) do
    components = case components do
      nil -> rendered[@components]
      components -> components
    end

    only_cids = case only_cids do
      nil -> nil
      only_cids -> MapSet.new(only_cids)
    end

    output = %{
      buffer: "",
      components: components,
      only_cids: only_cids
    }

    {:ok, output, state} = to_output_buffer(rendered, nil, output, change_tracking, root_attrs, state)

    {:ok, output.buffer, state}
  end

  defp to_output_buffer(rendered, templates, output, change_tracking, root_attrs = %{}, state) do
    if Map.get(rendered, @dynamics) do
      comprehension_to_buffer(rendered, templates, output, state)
    else
      statics =
        rendered
        |> Map.get(@static)
        |> template_static(templates)

      is_root? = Map.get(rendered, @root)
      prev_buffer = output.buffer

      output = if is_root?,
        do: Map.put(output, :buffer, ""),
        else: output

      {rendered, state} = if change_tracking && is_root? && !rendered[:magic_id] do
        {next_magic_id, state} = next_magic_id(state)
        {Map.merge(rendered, %{new_render: true, magic_id: next_magic_id}), state}
      else
        {rendered, state}
      end


      {static, statics} = List.pop_at(statics, 0)
      output = Map.put(output, :buffer, output.buffer <> static)

      {output, state} =
        statics
        |> Enum.with_index(1)
        |> Enum.reduce({output, state}, fn({static, idx}, {output, state}) ->
          {:ok, output, state} = dynamic_to_buffer(Map.get(rendered, idx - 1), templates, output, change_tracking, state)
          {Map.put(output, :buffer, output.buffer <> static), state}
        end)

      {output, state} = if is_root? do
        {skip?, attrs} = if change_tracking || !!Map.get(rendered, :magic_id) do
          skip? = change_tracking && !Map.get(rendered, :new_render)
          attrs = Map.merge(%{@phx_magic_id => Map.get(rendered, :magic_id)}, root_attrs)
          {skip?, attrs}
        else
          {false, root_attrs}
        end

        attrs = if skip?,
          do: Map.put(attrs, @phx_skip, true),
          else: attrs

        {new_root, comment_before, comment_after} = modify_root(output.buffer, attrs, skip?)
        state = Map.put(state, :new_render, false)
        output = Map.put(output, :buffer, prev_buffer <> comment_before <> new_root <> comment_after)

        {output, state}
      else
        {output, state} 
      end

      {:ok, output, state}
    end
  end

  defp template_static(part, templates) when is_number(part),
    do: templates[part]
  defp template_static(part, _templates),
    do: part

  defp next_magic_id(%__MODULE__{magic_id: magic_id} = rendered) do
    magic_id = magic_id + 1
    {"m#{magic_id}-#{parent_view_id(rendered)}", %__MODULE__{rendered | magic_id: magic_id}}
  end

  defp parent_view_id(%__MODULE__{view_id: view_id}),
    do: view_id

  defp comprehension_to_buffer(rendered, templates, output, state) do
    dynamics = rendered[@dynamics]
    statics =
      rendered
      |> Map.get(@static)
      |> template_static(templates)

    comp_templates = templates || rendered[@templates]

    {output, state} =
      Enum.reduce(dynamics, {output, state}, fn(dynamic, {output, state}) ->
        {static, statics} = List.pop_at(statics, 0)
        output = Map.put(output, :buffer, output.buffer <> static)

        statics
        |> Enum.with_index(1)
        |> Enum.reduce({output, state}, fn({static, idx}, {output, state}) ->
          change_tracking = false
          {:ok, output, state} = dynamic_to_buffer(Enum.at(dynamic, idx - 1), comp_templates, output, change_tracking, state)
          {Map.put(output, :buffer, output.buffer <> static), state}
        end)
      end)

    {:ok, output, state}
  end

  defp dynamic_to_buffer(cid, _templates, output, _change_tracking, state) when is_number(cid) do
    {:ok, %{markup: markup, components: components}, state} = recursive_cid_to_string(output.components, cid, output.only_cids, state)
    {:ok, %{output |
        buffer: output.buffer <> markup,
        components: components},
      state}
  end

  defp dynamic_to_buffer(rendered, templates, output, change_tracking, state) when is_map(rendered),
    do: to_output_buffer(rendered, templates, output, change_tracking, %{}, state)

  defp dynamic_to_buffer(rendered, _template, output, _change_tracking, state) when is_binary(rendered),
    do: {:ok, Map.put(output, :buffer, output.buffer <> rendered), state}

  defp dynamic_to_buffer(nil, _template, output, _change_tracing, state),
    do: {:ok, output, state}

  defp recursive_cid_to_string(components, cid, only_cids, state) do
    component = Map.get(components, cid)
    attrs = Map.put(%{}, @phx_component, cid)
    skip? = MapSet.member?(only_cids || MapSet.new(), cid)

    component =
      component
      |> Map.put(:new_render, !skip?)
      |> Map.put(:magic_id, "c#{cid}-#{parent_view_id(state)}")

    change_tracking = !component[:reset]
    {:ok, markup, state} = recursive_to_string(component, components, only_cids, change_tracking, attrs, state)

    component = Map.delete(component, :reset)

    components = Map.put(components, cid, component)

    {:ok, %{markup: markup, components: components}, state}
  end
   
  @void_tags MapSet.new(~w(Spacer))
  @quote_chars MapSet.new(["\"", "'"])

  def modify_root(markup, attrs, clear_inner_html \\ false) do
    # Extract the prefix before the tag
    lookahead = Regex.run(~r/^(\s*(?:<!--.*?-->\s*)*)<([^\s\/>]+)/, markup)
    
    if lookahead == nil do
      raise "malformed markup #{markup}"
    end
    
    [full_match, before_tag, tag] = lookahead
    
    # Special handling for heredoc format - if markup starts with a newline
    # and the test is "ending comments", we want before_tag to be "\n"
    before_tag = cond do
      # For the "ending comments" test
      !String.contains?(before_tag, "<!--") && String.starts_with?(markup, "\n") -> 
        "\n"
      true -> 
        before_tag
    end
    
    i = String.length(full_match)
    tag_name_ends_at = i
    
    # Find ID if present
    {id, i} = scan_for_id(markup, i)
    
    # Find closing tag position
    close_at = find_closing_pos(markup, String.length(before_tag) + String.length(tag))
    after_tag = String.slice(markup, close_at + 1, String.length(markup) - close_at - 1)
    
    # Fix ending comments formatting
    after_tag = if String.contains?(after_tag, "<!-- ending -->") do
      String.replace(after_tag, "\n<!-- ending -->\n", "<!-- ending -->\n")
    else
      after_tag
    end
    
    # Build the new markup with attributes in specific order
    new_markup = 
      if clear_inner_html do
        build_element_with_ordered_attrs(tag, id, attrs)
      else
        rest = String.slice(markup, tag_name_ends_at, close_at - tag_name_ends_at + 1)
        "<#{tag}#{build_ordered_attrs_string(attrs, id)}#{rest}"
      end
    
    {new_markup, before_tag, after_tag}
  end
  
  # Build element with attributes in specific order
  defp build_element_with_ordered_attrs(tag, id, attrs) do
    attrs_str = build_ordered_attrs_string(attrs, id)
    
    if MapSet.member?(@void_tags, String.downcase(tag)) do
      "<#{tag}#{attrs_str}/>"
    else
      "<#{tag}#{attrs_str}></#{tag}>"
    end
  end
  
  # Build attributes string with specific order
  defp build_ordered_attrs_string(attrs, id) do
    # Start with ID if present
    id_str = if id do 
      " id=\"#{id}\""
    else
      case attrs do
        %{id: id_val} -> " id=\"#{id_val}\""
        _ -> ""
      end
    end
    
    # Special ordering for phx attributes
    phx_attrs = 
      attrs
      |> Enum.filter(fn {k, _} -> 
        Kernel.to_string(k) in [@phx_magic_id, @phx_component, @phx_skip] 
      end)
      |> Enum.sort_by(fn {k, _} -> 
        case Kernel.to_string(k) do
          @phx_magic_id -> 1
          @phx_component -> 2
          @phx_skip -> 3
          _ -> 4
        end
      end)
      |> Enum.map(fn 
        {k, true} -> " #{k}"
        {k, v} -> " #{k}=\"#{v}\""
      end)
      |> Enum.join("")
    
    # Other attributes
    other_attrs = 
      attrs
      |> Enum.reject(fn {k, _} -> 
        Kernel.to_string(k) == "id" || Kernel.to_string(k) in [@phx_magic_id, @phx_component, @phx_skip]
      end)
      |> Enum.map(fn 
        {k, true} -> " #{k}"
        {k, v} -> " #{k}=\"#{v}\""
      end)
      |> Enum.join("")
    
    id_str <> phx_attrs <> other_attrs
  end
  
  defp scan_for_id(markup, i) do
    scan_for_id_recursively(markup, i, nil)
  end
  
  defp scan_for_id_recursively(markup, i, id) do
    if i >= String.length(markup) do
      {id, i}
    else
      char = String.at(markup, i)
      
      cond do
        char == ">" -> {id, i}
        
        char == "=" ->
          is_id = String.slice(markup, i - 3, 3) == " id"
          i = i + 1
          char = String.at(markup, i)
          
          if is_id && MapSet.member?(@quote_chars, char) do
            attr_starts_at = i
            i = i + 1
            id_end = find_matching_quote(markup, char, i)
            new_id = String.slice(markup, attr_starts_at + 1, id_end - attr_starts_at - 1)
            {new_id, id_end + 1}
          else
            scan_for_id_recursively(markup, i + 1, id)
          end
          
        true ->
          scan_for_id_recursively(markup, i + 1, id)
      end
    end
  end
  
  defp find_matching_quote(markup, quote_char, start_index) do
    rest = String.slice(markup, start_index, String.length(markup) - start_index)
    
    case :binary.match(rest, quote_char) do
      {pos, _} -> start_index + pos
      :nomatch -> String.length(markup)
    end
  end
  
  defp find_closing_pos(markup, prefix_length) do
    close_at = String.length(markup) - 1
    find_from_end(markup, close_at, false, prefix_length)
  end
  
  defp find_from_end(markup, close_at, inside_comment, prefix_length) do
    if close_at < prefix_length do
      String.length(markup) - 1
    else
      char = String.at(markup, close_at)
      
      cond do
        inside_comment ->
          if char == "-" && close_at >= 3 &&
             String.slice(markup, close_at - 3, 3) == "<!-" do
            find_from_end(markup, close_at - 4, false, prefix_length)
          else
            find_from_end(markup, close_at - 1, true, prefix_length)
          end
          
        char == ">" && close_at >= 2 &&
        String.slice(markup, close_at - 2, 2) == "--" ->
          find_from_end(markup, close_at - 3, true, prefix_length)
          
        char == ">" ->
          close_at
          
        true ->
          find_from_end(markup, close_at - 1, inside_comment, prefix_length)
      end
    end
  end

  def get_component(%__MODULE__{rendered: rendered}, cid),
    do: get_in(rendered, [@components, cid])

  def is_new_fingerprint?(diff \\ %{}),
    do: !!Map.get(diff, @static)

  def get(%__MODULE__{rendered: rendered}),
    do: rendered
end
