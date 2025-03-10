defmodule Crane.GRPC.Window do
  use GRPC.Server, service: Crane.Protos.Browser.WindowService.Service
  alias Crane.{Browser.Window, Protos}

  def visit(request, _stream) do
    {:ok, window} = Window.get(String.to_existing_atom(request.window_name))

    {:ok, response, _window} = Window.visit(window, to_request_opts(request))

    %Protos.Browser.Response{body: response.body}
  end

  def fetch(request, _stream) do
    {:ok, window} = Window.get(String.to_existing_atom(request.window_name))

    {:ok, response, _window} = Window.fetch(window, to_request_opts(request))

    %Protos.Browser.Response{body: response.body}
  end

  def forward(request, _stream) do
    {:ok, window} = Window.get(String.to_existing_atom(request.name))

    {:ok, response, _window} = Window.forward(window)

    %Protos.Browser.Response{body: response.body}
  end

  def back(request, _stream) do
    {:ok, window} = Window.get(String.to_existing_atom(request.name))

    {:ok, response, _window} = Window.back(window)

    %Protos.Browser.Response{body: response.body}
  end

  defp to_request_opts(%Protos.Browser.Request{url: url, method: _method, headers: _headers}) do
    [url: url]
  end
end
