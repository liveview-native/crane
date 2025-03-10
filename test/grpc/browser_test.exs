defmodule Crane.GRPC.BrowserTest do
  use GRPC.Integration.TestCase

  alias Crane.GRPC.Browser, as: Server
  alias Crane.Protos.BrowserService.Stub, as: Client
  alias Crane.Protos

  describe "get" do
    test "will get a the Browser struct" do
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

  describe "new_window" do
    test "will spawn a new window on the browser" do
      run_server(Server, fn port ->
        {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

        {:ok, %Protos.Browser.Window{} = _window} = Client.new_window(channel, %Protos.Browser{})
      end)
    end
  end
end
