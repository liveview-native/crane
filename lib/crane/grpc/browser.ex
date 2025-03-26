defmodule Crane.GRPC.Browser do
  use GRPC.Server, service: Crane.Protos.BrowserService.Service
  alias Crane.{Browser, Protos}

  def get(%Protos.Browser{headers: headers}, _stream) do
    headers = Enum.map(headers, fn(%{name: name, value: value}) ->
      {name, value}
    end)

    {:ok, browser} = Browser.get(%Browser{headers: headers})

    Browser.to_proto(browser)
  end
end
