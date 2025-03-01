defmodule Window.Window do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :id, 1, type: :string
end

defmodule Window.SubscribeRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :window_id, 1, type: :string, json_name: "windowId"
  field :headers, 2, repeated: true, type: Window.Header
end

defmodule Window.Request do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :window_id, 1, type: :string, json_name: "windowId"
  field :url, 2, type: :string
  field :method, 3, type: :string
  field :headers, 4, repeated: true, type: Window.Header
end

defmodule Window.Header do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :name, 1, type: :string
  field :value, 2, type: :string
end

defmodule Window.Message do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :data, 1, type: :string
end

defmodule Window.Response do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3

  field :node, 1, type: Node.Node
  field :headers, 2, repeated: true, type: Window.Header
end

defmodule Window.Empty do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.14.1", syntax: :proto3
end
