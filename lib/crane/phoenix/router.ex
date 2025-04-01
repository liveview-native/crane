defmodule Crane.Phoenix.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {PhoenixPlayground.Layout, :root}
    plug :put_secure_browser_headers
  end

  scope "/" do
    pipe_through :browser

    live "/", Crane.Phoenix.Live.Console
    live "/window/:name", Crane.Phoenix.Live.Window
  end
end
