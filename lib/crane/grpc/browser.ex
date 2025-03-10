defmodule Crane.GRPC.Browser do
  use GRPC.Server, service: Crane.Protos.BrowserService.Service
  alias Crane.{Browser, Browser.Window, Protos}

  def new_window(_empty, _stream) do
    {:ok, window} = Browser.new_window()

    Window.to_proto(window)
  end

  def get(%Protos.Browser{headers: headers}, _stream) do
    headers = Enum.map(headers, fn(%{name: name, value: value}) ->
      {name, value}
    end)

    {:ok, browser} = Browser.get(%Browser{headers: headers})

    Browser.to_proto(browser)
  end
end
