# Crane

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `crane` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:crane, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/crane>.

```sh
protoc -I priv/protos --swift_opt=Visibility=Public --swift_out=./Sources/Crane/generated $(find priv/protos -name '*.proto' ! -name 'elixirpb.proto')
protoc -I priv/protos --grpc-swift_out=./Sources/Crane/generated $(find priv/protos -name '*.proto' ! -name 'elixirpb.proto')
```

```sh
mix elixir_kit --sdk iphonesimulator --application crane --output ElixirKitCrane
```