defmodule LiveView.DOM do
  @phx_sticky "data-phx-sticky"

  def is_phx_sticky?(node),
    do: Floki.attribute(node, @phx_sticky) != []

  def set_attributes({tag_name, attributes, children}, attr_map) do
    attributes =
      Enum.into(attributes, %{})
      |> Map.merge(attr_map)
      |> Map.to_list()

    {tag_name, attributes, children}
  end

  def get_attribute({_tag_name, attributes, _children}, attr_name),
    do: Enum.find_value(attributes, fn 
      {^attr_name, attr_value} -> attr_value
      _other -> nil
    end)
end
