defmodule Crane.GRPC.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Server.Interceptors.Logger
  run Crane.GRPC.Browser
  run Crane.GRPC.Window, interceptors: [Crane.LiveViewNative]
end
