defmodule Crane.Protos.Browser.Window.History.Frame.StateEntry do
  @moduledoc false

  use Protobuf, map: true, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule Crane.Protos.Browser.Window.History.Frame do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :state, 1,
    repeated: true,
    type: Crane.Protos.Browser.Window.History.Frame.StateEntry,
    map: true

  field :url, 2, type: :string
end
