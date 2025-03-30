defmodule Crane.Application do
  # use Application
  # def start(_type, _args) do
  #   children = [
  #
  #     {GRPC.Server.Supervisor, endpoint: Crane.Endpoint.GRPC, port: 50051, start_server: true},
  #     # {PhoenixPlayground, live: Crane.Phoenix.Live.Console, open_browser: false}
  #   ]
  #
  #   opts = [strategy: :one_for_one, name: __MODULE__]
  #   Supervisor.start_link(children, opts)
  # end
end

