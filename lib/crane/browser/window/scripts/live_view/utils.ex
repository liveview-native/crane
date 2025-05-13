defmodule LiveView.Utils do
  def is_cid?(cid) when is_number(cid),
    do: true
  def is_cid?(cid) when is_binary(cid),
    do: Regex.match?(~r/^(0|[1-9]\d*)$/, cid)
  def is_cid?(_cid),
    do: false
end
