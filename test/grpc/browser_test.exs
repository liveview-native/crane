defmodule Crane.GRPC.BrowserTest do
  use GRPC.Integration.TestCase

  alias Crane.GRPC.Browser, as: Server
  alias Crane.Protos.BrowserService.Stub, as: Client
  alias Crane.Protos

  setup do
    {:ok, browser_pid} = Crane.Browser.start_link([])

    on_exit fn ->
      Process.exit(browser_pid, :normal)
    end

    :ok
  end

  describe "get" do
    test "will get the Browser struct" do
      run_server(Server, fn port ->
        {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

        headers = [
          %Crane.Protos.Browser.Header{name: "Accept", value: "application/gameboy"}
        ]

        {:ok, %Protos.Browser{} = browser} = Client.get(channel, %Protos.Browser{headers: headers})

        Enum.each(headers, fn(header) ->
          assert Enum.member?(browser.headers, header)
        end)
      end)
    end
  end
end
