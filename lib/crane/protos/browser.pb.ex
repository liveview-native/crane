defmodule Crane.Protos.Browser do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :name, 1, type: :string
  field :windows, 2, repeated: true, type: :string
  field :headers, 3, repeated: true, type: Crane.Protos.Browser.Header
end

defmodule Crane.Protos.BrowserService.Service do
  @moduledoc false

  use GRPC.Service, name: "BrowserService", protoc_gen_elixir_version: "0.14.1"

  rpc :Get, Crane.Protos.Browser, Crane.Protos.Browser

  rpc :CloseWindows, Crane.Protos.Browser, Crane.Protos.Empty
end

defmodule Crane.Protos.BrowserService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Crane.Protos.BrowserService.Service
end
