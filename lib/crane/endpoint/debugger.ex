defmodule Crane.Endpoint.Debugger do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/json" do
    # Adjust the host and port values to match your server’s address.
    host = "localhost" 
    targets = [
      %{
        "description" => "",
        "devtoolsFrontendUrl" => "chrome-devtools://devtools/bundled/inspector.html?ws=#{host}:4000/ws",
        "id" => "1",
        "title" => "Elixir Debug Target",
        "type" => "page",
        "url" => "http://#{host}/",
        "webSocketDebuggerUrl" => "ws://#{host}:4000/ws"
      }
    ]
    send_resp(conn, 200, Jason.encode!(targets))
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
