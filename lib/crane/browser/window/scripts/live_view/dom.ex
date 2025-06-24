defmodule LiveView.DOM do
  use LiveView.Constants, [
    :phx_component,
    :phx_parent_id,
    :phx_private,
    :phx_sticky,
    :phx_session,
    :phx_upload_ref,
    :phx_view_ref
  ]

  alias GenDOM.{
    Document,
    Element
  }

  def by_id(%Document{} = document, id) do
    GenDOM.Document.get_element_by_id(document, id)
    |> case do
      nil ->
        # log - "no id found for #{id}"
        nil
      element -> element
    end
  end

  def remove_class(element, class_name) do
    Element.merge(element, %{
      class_list: Enum.reject(element.class_list, &(&1 == class_name))
    })
  end

  def all(nil, _query) do
    []
  end

  def all(node, query) do
    apply(node.__struct__, :query_selector_all, [node, query])
  end

  def all(nil, _query, _callback) do
    []
  end

  def all(node, query, callback) do
    elements = apply(node.__struct__, :query_selector_all, [node, query])

    if callback do
      Enum.each(elements, &(callback.(&1)))
    else
      elements
    end
  end

  def child_node_length(vml) do
    # TODO
  end

  def is_upload_input?(%Element{} = element) do
    # TODO
  end

  def is_auto_upload?(%Element{} = element) do
    !!Map.get(element.attributes, "data-phx-auto-upload")
  end

  def find_upload_inputs(node) do
    document = GenServer.call(node.owner_document, :get)
    form_id = node.id
    inputs_outside_form = all(document, ~s'input[type="file"][#{@phx_upload_ref}][form="#{form_id}"])')

    all(node, ~s'input[type="file"][#{@phx_upload_ref}]') ++ inputs_outside_form
  end

  def find_component_node_list(view_id, cid, document) do
    all(document, ~s'[#{@phx_view_ref}="#{view_id}"][#{@phx_component}="#{cid}"]')
  end

  def is_phx_destroyed?(node) do
    !!(node.id == "" && private(node, "destroyed"))
  end

  def wants_new_tab(event) do
    # TODO
  end

  def is_unloadable_form_submit(event) do
    # TODO
  end

  def is_new_page_click(event, current_location) do
    # TODO
  end

  def mark_phx_child_destroyed(element) do
    if is_phx_child?(element) do
      Element.set_attribute(element, @phx_session, "")
    end

    put_private(element, "destroyed", true)
  end

  def find_phx_children_in_fragment(vml, parent_id) do
    template = Document.create_element("Template")
    Element.inner_html(template, vml)
    find_phx_children(template, parent_id)
  end

  def is_ignored?(element, phx_update) do
    Element.get_attribute(element, phx_update) || Element.get_attribute(element, "data-phx-update") == "ignore"
  end

  def is_phx_update?(element, phx_update, update_types) do
    Enum.member?(update_types, Element.get_attribute(element, phx_update))
  end

  def find_phx_sticky(element) do
    all(element, "[#{@phx_sticky}]")
  end

  def find_existing_parent_cids(document, view_id, cids) do
    {parent_cids, children_cids} =
      Enum.reduce(cids, {MapSet.new(), MapSet.new()}, fn(cid, {parent_cids, children_cids}) ->
        all(document, ~s'[#{@phx_view_ref}="#{view_id}"][#{@phx_component}="#{cid}"]')
        |> Enum.reduce({parent_cids, children_cids}, fn(parent, {parent_cids, children_cids}) ->
          parent_cids = MapSet.put(parent_cids, cid)

          children_cids =
            all(parent, ~s'[#{@phx_view_ref}="#{view_id}"][#{@phx_component}]')
            |> Enum.map(fn(element) -> Integer.parse_int(Element.get_attribute(element, @phx_component)) end)
            |> Enum.reduce(children_cids, &MapSet.put(&2, &1))

          {parent_cids, children_cids}
        end)
      end)

    MapSet.difference(parent_cids, children_cids)
  end

  def private(element, key) do
    get_in(element, [@phx_private, key])
  end

  def delete_private(element, key) do
    assigns = Map.delete(element.assigns, key)
    Element.assign(element, assigns)
  end

  def put_private(element, key, value) do
    Element.assign(element, key, value)
  end

  def update_private(element, key, default, fun) do
    if existing = private(element, key),
      do: put_private(element, key, fun.(existing)),
      else: put_private(element, key, fun.(default))
  end

  def sync_pending_attrs(from_element, to_element) do
    if Element.has_attribute?(from_element, @phx_ref_src) do
      Enum.each(@phx_event_classes, fn(class_name) ->
        Enum.member?(from_element.class_list, class_name)
          && Element.put(to_element, :class_list, List.insert_at(to_element.class_list, -1, class_name))
      end)

      Enum.filter(@phx_pending_attrs, &Element.has_attribute?(from_element, &1))
      |> Enum.each(fn(attr) ->
        Element.set_attribute(to_element, attr, Element.get_attribute(from_element, attr))
      end)
    end
  end

  def copy_privates(target, source) do
    Element.assign(target, source.assigns)
  end

  def put_title(title) do
    # TODO
  end

  def debounce(element, event, phx_debounce, default_debounce, phx_throttle, default_throttle, async_filter, callback) do
    debounce = case Element.get_attribute(element, phx_debounce) do
      "" -> default_debounce
      debounce -> debounce
    end

    throttle = case Element.get_attribute(element, phx_throttle) do
      "" -> default_throttle
      debounce -> debounce
    end

    cond do
      debounce && debounce != "" -> debounce
      throttle && throttle != "" -> throttle
    end
    |> case do
      nil -> callback.()

      "blur" ->
        inc_cycle(element, "debounce-blur-cycle", fn() ->
          if (async_filter.()),
            do: callback.()
        end)

        if once(element, "debounce-blur"),
          do: Element.add_event_listener(element, "blur", &trigger_cycle(&1, "debounce-blur-cycle"))

      value ->
        case Integer.parse(value) do
          :error ->
            # TODO Logger
            nil
          {timeout, _} ->
            trigger = fn ->
              if throttle,
                do: delete_private(element, @throttled),
                else: callback.()
            end

            current_cycle = inc_cycle(element, @debounce_trigger, trigger)

            if throttle do
              new_key_down = if event.type == "keydown" do
                prev_key = private(element, @debounce_prev_key)
                Element.put_private!(element, @debounce_prev_key, event.key)
                prev_key == event.key
              else
                false
              end

              if !new_key_down && private(element, @throttled) do
                false
              else
                callback.()
                task = Task.async(fn ->
                  :timer.sleep timeout
                  if async_filter.(),
                    do: trigger_cycle(element, @debounce_trigger)
                end)

                put_private(element, @throttled, task)
              end
            else
              Task.async(fn ->
                if async_filter.() do
                  trigger_cycle(element, @debounce_trigger, current_cycle)
                end
              end)
            end

            form = element.form
        end
    end
  end

  def inc_cycle(a, b, c), do: raise "not implemented"

  def once(a, b), do: raise "not implemented"

  def is_phx_child?(element), do: raise "not implemented"

  def trigger_cycle(element, trigger, cycle \\ nil), do: raise "not implemented"

  def find_phx_children(a, b), do: raise "not implemented"
end
