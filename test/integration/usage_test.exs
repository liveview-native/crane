defmodule Crane.Integration.UsageTest do
  use GRPC.Integration.TestCase

  alias Crane.GRPC.Browser, as: BrowserServer
  alias Crane.GRPC.Window, as: WindowServer
  alias Crane.Protos.BrowserService.Stub, as: BrowserClient
  alias Crane.Protos.Browser.WindowService.Stub, as: WindowClient
  alias Crane.Protos

  setup do
    {:ok, browser_pid} = Crane.Browser.start_link([])
    fetch_req_options = Application.get_env(:crane, :fetch_req_options, [])
    Application.put_env(:crane, :fetch_req_options, [])

    on_exit(fn -> 
      Application.put_env(:crane, :fetch_req_options, fetch_req_options)
      Process.exit(browser_pid, :normal)
    end)

    :ok
  end

  test "bad uri" do
    run_server([BrowserServer, WindowServer], fn port ->
      {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

      headers = [
        %Protos.Browser.Header{name: "Accept", value: "application/gameboy"}
      ]

      {:ok, browser} = BrowserClient.get(channel, %Protos.Browser{headers: headers})

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
