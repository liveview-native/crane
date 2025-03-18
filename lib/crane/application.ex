defmodule Crane.Application do
  use Application
  def start(_type, _args) do
    children = [
      {Crane.Browser, []},
      {GRPC.Server.Supervisor, endpoint: Crane.Endpoint.GRPC, port: 50051, start_server: true}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end
end

