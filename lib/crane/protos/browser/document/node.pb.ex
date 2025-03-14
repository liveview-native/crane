defmodule Crane.Protos.Browser.Document.Node do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :type, 1, type: :string
  field :tag_name, 2, type: :string, json_name: "tagName"
  field :attributes, 3, repeated: true, type: Crane.Protos.Browser.Document.Node.Attribute
  field :children, 4, repeated: true, type: Crane.Protos.Browser.Document.Node
  field :text_content, 5, type: :string, json_name: "textContent"
  field :id, 6, type: :int32
end
