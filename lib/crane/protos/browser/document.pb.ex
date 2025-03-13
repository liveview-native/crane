defmodule Crane.Protos.Browser.Document do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :nodes, 4, repeated: true, type: Crane.Protos.Browser.Document.Node
end
