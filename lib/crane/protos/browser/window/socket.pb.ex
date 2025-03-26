defmodule Crane.Protos.Browser.Window.Socket do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :name, 1, type: :string
  field :window_name, 2, type: :string, json_name: "windowName"
  field :url, 3, type: :string
  field :headers, 4, repeated: true, type: Crane.Protos.Browser.Header
end

defmodule Crane.Protos.Browser.Window.SocketService.Service do
  @moduledoc false

  use GRPC.Service, name: "SocketService", protoc_gen_elixir_version: "0.14.1"

  rpc :New, Crane.Protos.Browser.Window.Socket, Crane.Protos.Browser.Window.Socket

  rpc :Send, Crane.Protos.Browser.Window.Socket.Message, Crane.Protos.Empty

  rpc :Receive,
      Crane.Protos.Browser.Window.Socket,
      stream(Crane.Protos.Browser.Window.Socket.Message)
end

defmodule Crane.Protos.Browser.Window.SocketService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Crane.Protos.Browser.Window.SocketService.Service
end
