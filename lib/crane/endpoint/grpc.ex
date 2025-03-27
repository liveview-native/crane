defmodule Crane.Endpoint.GRPC do
  use GRPC.Endpoint

  intercept GRPC.Server.Interceptors.Logger
  run Crane.GRPC.Browser
  run Crane.GRPC.Window, interceptors: [Crane.Interceptors.Fuse]
  run Crane.GRPC.Socket
end
