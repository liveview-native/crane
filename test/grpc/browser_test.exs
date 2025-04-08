defmodule Crane.GRPC.BrowserTest do
  use GRPC.Integration.TestCase

  alias Crane.GRPC.Browser, as: Server
  alias Crane.Protos.BrowserService.Stub, as: Client
  alias Crane.Protos

  describe "new" do
    test "will return a new browser" do
      run_server(Server, fn port ->
        {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

        {:ok, %Protos.Browser{} = browser} = Client.new(channel, %Protos.Empty{})

        pid = Process.whereis(String.to_existing_atom(browser.name))

        assert Process.alive?(pid)
      end)
    end
  end

  describe "get" do
    test "will get the Browser struct" do
      run_server(Server, fn port ->
        {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

        {:ok, browser} = Crane.Browser.new()

        {:ok, %Protos.Browser{} = proto_browser} = Client.get(channel, Crane.Browser.to_proto(browser))

        assert String.to_existing_atom(proto_browser.name) == browser.name
      end)
    end
  end
end
