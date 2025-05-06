defmodule LiveView.DOM do
  @phx_sticky "data-phx-sticky"

  def is_phx_sticky?(node),
    do: Floki.attribute(node, @phx_sticky) != []
end
