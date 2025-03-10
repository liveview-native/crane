defmodule Crane.Protos.Browser.Response do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :body, 1, type: :string
  field :view_tree, 2, type: Crane.Protos.Browser.Node, json_name: "viewTree"
  field :headers, 3, repeated: true, type: Crane.Protos.Browser.Header
  field :status, 4, type: :int32
end
