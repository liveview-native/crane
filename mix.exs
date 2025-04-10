defmodule Crane.MixProject do
  use Mix.Project

  def project do
    [
      app: :crane,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      protoc: &run_protoc/1
    ]
  end

  def application do
    [
      mod: {Crane.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp run_protoc(_args) do
    System.cmd("sh", [
      "-c",
      "rm -rf lib/crane/protos/*",
    ])
    System.cmd("sh", [
      "-c",
      "protoc -I priv/protos --elixir_out=plugins=grpc,paths=source_relative:./lib/crane/protos $(find priv/protos -name '*.proto' ! -name 'elixirpb.proto')"
    ])
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:phoenix_playground, github: "bcardarella/phoenix_playground", branch: "bc-release-compat"},
      {:mint_web_socket, "~> 1.0.4"},
      {:floki, "~> 0.37"},
      {:websockex, "~> 0.4"},
      {:http_cookie, "~> 0.7"},
      {:public_suffix, github: "axelson/publicsuffix-elixir"},
      {:live_view_native, github: "liveview-native/live_view_native"},
      {:test_server, "~> 0.1", only: :test},
      {:bandit, "~> 1.0"},
      {:cdpotion, "~> 0.1.0"},

      {:elixirkit, github: "liveview-native/elixirkit", branch: "main"},

      {:plug_crypto, github: "elixir-plug/plug_crypto", branch: "main", override: true},
    ]
  end
end
