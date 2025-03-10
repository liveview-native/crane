import Config

config :crane, fetch_req_options: [
  plug: {Req.Test, Crane.Browser.Window}
]

