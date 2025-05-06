defmodule Crane.ResourceTest do
  use ExUnit.Case
  import Crane.Test.Utils

  alias Crane.{Browser, Browser.Window}

  setup config do
    Application.put_env(:crane, :pubsub, config.test)
    start_pubsub(config)

    on_exit fn ->
      Application.delete_env(:crane, :pubsub)
    end

    :ok
  end
end

