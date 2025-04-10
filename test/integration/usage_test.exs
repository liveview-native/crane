defmodule Crane.Integration.UsageTest do
  use GRPC.Integration.TestCase

  alias Crane.GRPC.Browser, as: BrowserServer
  alias Crane.GRPC.Window, as: WindowServer
  alias Crane.Protos.BrowserService.Stub, as: BrowserClient
  alias Crane.Protos.Browser.WindowService.Stub, as: WindowClient
  alias Crane.Protos

  setup do
    {:ok, browser, _crane} = Crane.new_browser()
    fetch_req_options = Application.get_env(:crane, :fetch_req_options, [])
    Application.put_env(:crane, :fetch_req_options, [])

    on_exit(fn -> 
      Application.put_env(:crane, :fetch_req_options, fetch_req_options)
    end)

    {:ok, browser: browser}
  end

  @tag :skip
  test "bad uri", %{browser: browser} do
    run_server([BrowserServer, WindowServer], fn port ->
      {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

      request = Crane.Browser.to_proto(browser)

      {:ok, browser} = BrowserClient.get(channel, request)

      {:ok, window} = WindowClient.new(channel, %Protos.Browser.Window{browser_name: browser.name})

      request = %Protos.Browser.Request{
        url: "bad-uri",
        window_name: window.name
      }

      {:ok, response} = WindowClient.visit(channel, request)

      assert response.status == 400
    end)
  end
end
