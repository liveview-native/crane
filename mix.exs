defmodule Crane.MixProject do
  use Mix.Project

  def project do
    [
      app: :crane,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:floki, "~> 0.37"},
      {:websockex, "~> 0.4"},
      {:http_cookie, "~> 0.7"},
      {:public_suffix, github: "axelson/publicsuffix-elixir"},
      {:live_view_native, path: "../live_view_native"},
      {:grpc, github: "elixir-grpc/grpc"},
      # {:protobuf_generate, github: "drowzy/protobuf_generate"},
      {:protobuf_generate, path: "../protobuf_generate"},
      {:test_server, "~> 0.1", only: :test},
    ]
  end
end
