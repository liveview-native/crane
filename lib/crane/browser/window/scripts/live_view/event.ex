defmodule LiveView.Event do
  defstruct [
    isTrusted: false,
    type: nil,
    detail: %{}
  ]
end
