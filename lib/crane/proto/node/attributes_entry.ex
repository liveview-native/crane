defmodule Crane.Proto.Node.Attribute do
  @moduledoc false
  use Protobuf, map: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :name, 1, type: :string
  field :value, 2, type: :string
end
