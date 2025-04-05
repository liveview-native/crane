defmodule Crane.Application do
 use Application

  @live_reload Application.compile_env(:phoenix_playground, :live_reload)

  def start(_type, _args) do

   children = [
      {Crane, []},
      {GRPC.Server.Supervisor, endpoint: Crane.Endpoint.GRPC, port: 50051, start_server: true},
      {PhoenixPlayground, plug: Crane.Phoenix.Router, live_reload: @live_reload, open_browser: false}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end
end

