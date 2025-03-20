defmodule Crane.Protos.Browser.Window.Socket do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :name, 1, type: :string
end

defmodule Crane.Protos.Browser.Window.SocketService.Service do
  @moduledoc false

  use GRPC.Service, name: "SocketService", protoc_gen_elixir_version: "0.14.1"

  rpc :Send, Crane.Protos.Browser.Window.Socket.Message, Crane.Protos.Empty

  rpc :Receive,
      Crane.Protos.Browser.Window.Socket,
      stream(Crane.Protos.Browser.Window.Socket.Message)
end

defmodule Crane.Protos.Browser.Window.SocketService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Crane.Protos.Browser.Window.SocketService.Service
end
