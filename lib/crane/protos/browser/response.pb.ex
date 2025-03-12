defmodule Crane.Protos.Browser.Response.ViewTreesEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: Crane.Protos.Browser.Node
end

defmodule Crane.Protos.Browser.Response do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :body, 1, type: :string

  field :view_trees, 2,
    repeated: true,
    type: Crane.Protos.Browser.Response.ViewTreesEntry,
    json_name: "viewTrees",
    map: true

  field :stylesheets, 3, repeated: true, type: :string
  field :headers, 4, repeated: true, type: Crane.Protos.Browser.Header
  field :status, 5, type: :int32
  field :history, 6, type: Crane.Protos.Browser.Window.History
end
