defmodule Crane.Protos.Browser.Window.History do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :index, 1, type: :int32
  field :stack, 2, repeated: true, type: Crane.Protos.Browser.Window.History.Frame
end
