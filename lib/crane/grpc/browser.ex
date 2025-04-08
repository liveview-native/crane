defmodule Crane.GRPC.Browser do
  use GRPC.Server, service: Crane.Protos.BrowserService.Service
  alias Crane.{Browser, Protos}

  def new(%Protos.Empty{}, _stream) do
    {:ok, browser, _crane} = Crane.new_browser()

    Browser.to_proto(browser)
  end

  def get(%Protos.Browser{name: name, headers: headers}, _stream) do
    headers = Enum.map(headers, fn(%{name: name, value: value}) ->
      {name, value}
    end)

    {:ok, browser} = Browser.get(%Browser{name: name, headers: headers})

    Browser.to_proto(browser)
  end
end
