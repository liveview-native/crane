defmodule Crane.GRPC.Window do
  use GRPC.Server, service: Crane.Protos.Browser.WindowService.Service
  alias Crane.{Browser.Window, Protos}

  def visit(request, _stream) do
    window = Window.get(String.to_atom(request.window_name))

    {:ok, response, _window} = Window.visit(window, to_request_opts(request))

    %Protos.Browser.Window.Response{body: response.body}
  end

  defp to_request_opts(%Protos.Browser.Window.Request{url: url, method: _method, headers: _headers}) do
    [url: url]
  end
end
