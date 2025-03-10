defmodule Crane.Protos.Browser.Request do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :window_name, 1, type: :string, json_name: "windowName"
  field :url, 2, type: :string
  field :method, 3, type: :string
  field :headers, 4, repeated: true, type: Crane.Protos.Browser.Header
end
