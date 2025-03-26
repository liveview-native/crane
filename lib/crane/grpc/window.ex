defmodule Crane.GRPC.Window do
  use GRPC.Server, service: Crane.Protos.Browser.WindowService.Service
  alias Crane.{
    Browser,
    Browser.Window,
    Browser.Window.History,
    Protos
  }

  @allowed_methods ~w{GET HEAD POST PUT DELETE CONNECT OPTIONS TRACE PATCH}

  def new(request, _stream) do
    {:ok, browser} = Browser.get(%Browser{name: String.to_existing_atom(request.browser_name)})
    {:ok, window} = Browser.new_window(%Window{browser_name: browser.name})

    Window.to_proto(window)
  end

  def visit(request, _stream) do
    {:ok, window} = Window.get(request.window_name)

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

  defp to_request_opts(%Protos.Browser.Request{method: method} = request) when method not in @allowed_methods,
    do: to_request_opts(%Protos.Browser.Request{request | method: "GET"})

  defp to_request_opts(%Protos.Browser.Request{url: url, method: method, headers: headers}) do
    [
      url: url,
      headers: decode_headers(headers),
      method: method
    ]
  end

  defp decode_headers(headers) do
    Enum.map(headers, fn
      %Protos.Browser.Header{name: name, value: value} -> {name, value}
    end)
  end

  defp build_response(response, window) do
    %Protos.Browser.Response{
      status: response.status,
      body: response.body,
      history: History.to_protoc(window.history)
    }
  end
end
