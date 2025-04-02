defmodule Crane.Application do
 use Application

  def start(_type, _args) do

    live_reload = Application.get_env(:phoenix_playground, :live_reload)

    grpc_port = System.get_env("GRPC_PORT", "50051") |> make_integer()
    phx_port = System.get_env("PHX_PORT", "4000") |> make_integer()

    children = [
      {Crane, []},
      {GRPC.Server.Supervisor, endpoint: Crane.Endpoint.GRPC, port: grpc_port, start_server: true},
      {PhoenixPlayground, plug: Crane.Phoenix.Router, live_reload: live_reload, open_browser: false, port: phx_port}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  defp make_integer(integer) when is_integer(integer),
    do: integer
  defp make_integer(integer) when is_binary(integer) do
    {integer, _} = Integer.parse(integer)

    integer
  end
end

