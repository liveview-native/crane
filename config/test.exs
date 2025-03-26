import Config

config :logger, :level, :debug
config :logger, :backends, []

config :crane, fetch_req_options: [
  plug: {Req.Test, Crane.Browser.Window}
]

config :crane, interceptors: [
  Crane.TestInterceptors.Socket
]
