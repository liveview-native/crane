defmodule Crane.Protos.Browser.Window do
  @moduledoc false

  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :name, 1, type: :string
  field :browser_name, 2, type: :string, json_name: "browserName"
  field :sockets, 3, repeated: true, type: :string
end

defmodule Crane.Protos.Browser.WindowService.Service do
  @moduledoc false

  use GRPC.Service, name: "WindowService", protoc_gen_elixir_version: "0.14.1"

  rpc :New, Crane.Protos.Browser.Window, Crane.Protos.Browser.Window

  rpc :Visit, Crane.Protos.Browser.Request, Crane.Protos.Browser.Response

  rpc :Fetch, Crane.Protos.Browser.Request, Crane.Protos.Browser.Response

  rpc :Refresh, Crane.Protos.Browser.Window, Crane.Protos.Browser.Response

  rpc :Forward, Crane.Protos.Browser.Window, Crane.Protos.Browser.Response

  rpc :Back, Crane.Protos.Browser.Window, Crane.Protos.Browser.Response

  rpc :Close, Crane.Protos.Browser.Window, Crane.Protos.Browser.Window
end

defmodule Crane.Protos.Browser.WindowService.Stub do
  @moduledoc false

  use GRPC.Stub, service: Crane.Protos.Browser.WindowService.Service
end
