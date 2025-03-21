defmodule Crane.GRPC.Window do
  use GRPC.Server, service: Crane.Protos.Browser.WindowService.Service
  alias Crane.{Browser.Window, Browser.Window.History, Protos}

  def visit(request, _stream) do
    {:ok, window} = Window.get(String.to_existing_atom(request.window_name))

    {:ok, response, window} = Window.visit(window, to_request_opts(request))

    build_response(response, window)
  end

  def fetch(request, _stream) do
    {:ok, window} = Window.get(String.to_existing_atom(request.window_name))

    {:ok, response, _window} = Window.fetch(window, to_request_opts(request))

    %Protos.Browser.Response{body: response.body}
  end

  def forward(request, _stream) do
    {:ok, window} = Window.get(String.to_existing_atom(request.name))

    {:ok, response, window} = Window.forward(window)

    build_response(response, window)
  end

  def back(request, _stream) do
    {:ok, window} = Window.get(String.to_existing_atom(request.name))

    {:ok, response, window} = Window.back(window)

    build_response(response, window)
  end

  def refresh(request, _stream) do
    {:ok, window} = Window.get(String.to_existing_atom(request.name))
    {:ok, response, window} = Window.go(window, 0)

    build_response(response, window)
  end

  def close(request, _stream) do
    {:ok, window} = Window.get(String.to_existing_atom(request.name))
    :ok = Window.close(window)

    %Protos.Browser.Window{
      name: ""
    }
  end

  defp to_request_opts(%Protos.Browser.Request{url: url, method: _method, headers: _headers}) do
    [url: url]
  end

  defp build_response(response, window) do
    %Protos.Browser.Response{
      status: response.status,
      body: response.body,
      history: History.to_protoc(window.history)
    }
  end
end
