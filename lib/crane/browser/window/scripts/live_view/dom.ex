defmodule LiveView.DOM do
  use LiveView.Constants, [
    :phx_parent_id,
    :phx_sticky,
    :phx_session
  ]

  def all(nil, _selector, _callback),
    do: []

  def all(node, selector) do
    node
    |> Floki.find(selector)
  end

  def is_phx_sticky?(node),
    do: Floki.attribute(node, @phx_sticky) != []

  def set_attributes({tag_name, attributes, children}, attr_map) do
    attributes =
      Enum.into(attributes, %{})
      |> Map.merge(attr_map)
      |> Map.to_list()

    {tag_name, attributes, children}
  end

  def get_attribute([el | _], attr_name),
    do: get_attribute(el, attr_name)

  def get_attribute({_tag_name, attributes, _children}, attr_name),
    do: Enum.find_value(attributes, fn 
      {^attr_name, attr_value} -> attr_value
      _other -> nil
    end)

  def find_phx_children(el, parent_id),
    do: all(el, ~S'[#{@phx_sessoin}][#{@phx_parent_id}="#{parent_id}"]')

  def has_attribute?(el, attribute),
    do: !!get_attribute(el, attribute)

  def put_sticky(el, name, op) do
    stashed_result = op.(el)

  end

  def private(el, key),
    do: has_attribute?(el, @phx_private)

  # defp update_private(%__MODULE__{} = dom_patch, el, key, default_vale, update_func) do
  #
  # end

  # defp put_private(%__MODULE__{private: private})
  
  # updatePrivate(el, key, defaultVal, updateFunc){
  #   let existing = this.private(el, key)
  #   if(existing === undefined){
  #     this.putPrivate(el, key, updateFunc(defaultVal))
  #   } else {
  #     this.putPrivate(el, key, updateFunc(existing))
  #   }
  # },
end
