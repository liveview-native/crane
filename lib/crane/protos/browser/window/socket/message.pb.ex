defmodule Crane.Protos.Browser.Window.Socket.Message do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :type, 1, type: :string
  field :data, 2, type: :string
  field :socket_name, 3, type: :string, json_name: "socketName"
end
