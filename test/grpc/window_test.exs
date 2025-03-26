defmodule Crane.GRPC.WindowTest do
  use GRPC.Integration.TestCase

  alias Crane.GRPC.Window, as: Server
  alias Crane.Browser.Window
  alias Crane.Protos.Browser.WindowService.Stub, as: Client
  alias Crane.Protos
  alias Plug.Conn

  import Crane.Test.Utils

  setup do
    {:ok, pid} = Window.start_link(%{})
    {:ok, window} = GenServer.call(pid, :get)
    
    Req.Test.stub(Window, fn(conn) ->
      case Conn.request_url(conn) do
        "https://dockyard.com/1" -> 
          Conn.send_resp(conn, 200, "<Text>1</Text>")
        "https://dockyard.com/2" -> 
          Conn.send_resp(conn, 200, "<Text>2</Text>")
        "https://dockyard.com/3" -> 
          Conn.send_resp(conn, 200, "<Text>3</Text>")
        "https://dockyard.com/4" -> 
          Conn.send_resp(conn, 200, "<Text>4</Text>")
        "https://dockyard.com/5" -> 
          Conn.send_resp(conn, 200, "<Text>#{:erlang.monotonic_time()}</Text>")
      end
    end)

    Req.Test.allow(Window, self(), pid_for(window))

    {:ok, _response, window} = Window.visit(window, url: "https://dockyard.com/1")
    {:ok, _response, window} = Window.visit(window, url: "https://dockyard.com/2")
    {:ok, _response, window} = Window.visit(window, url: "https://dockyard.com/3")

    {:ok, window: window}
  end

  describe "new" do
    test "will spawn a new window on the browser" do
      run_server(Server, fn port ->
        {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

        request = %Protos.Browser.Window{}

        {:ok, %Protos.Browser.Window{} = window} = Client.new(channel, request)

        refute request == window
      end)
    end
  end

  describe "visit" do
    test "will get the response from the url", %{window: window} do
      run_server(Server, fn port ->
        {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

        request =
          %Protos.Browser.Request{
            url: "https://dockyard.com/2",
            window_name: Atom.to_string(window.name)
          }

        {:ok, response} = Client.visit(channel, request)

        assert response.body == "<Text>2</Text>"
        assert response.status == 200

        assert length(response.history.stack) == 4
        assert response.history.index == 3
      end)
    end
  end

  describe "fetch" do
    test "will get the response from the url", %{window: window} do
      run_server(Server, fn port ->
        {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

        request =
          %Protos.Browser.Request{
            url: "https://dockyard.com/2",
            window_name: Atom.to_string(window.name)
          }

        {:ok, response} = Client.fetch(channel, request)

        assert response.body == "<Text>2</Text>"

        assert is_nil(response.history)
      end)
    end
  end

  describe "forward/back" do
    test "will traverse history", %{window: window} do
      run_server(Server, fn port ->
        {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

        request = Window.to_proto(window)
        
        assert length(window.history.stack) == 3

        {:ok, _response} = Client.back(channel, request)
        {:ok, response} = Client.back(channel, request)

        assert response.body == "<Text>1</Text>"
        assert length(response.history.stack) == 3
        assert response.history.index == 0

        {:ok, response} = Client.forward(channel, request)

        assert response.body == "<Text>2</Text>"
        assert length(response.history.stack) == 3
        assert response.history.index == 1
      end)
    end
  end

  describe "refresh" do
    test "will get the response from the url", %{window: window} do
      run_server(Server, fn port ->
        {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")

        request =
          %Protos.Browser.Request{
            url: "https://dockyard.com/5",
            window_name: Atom.to_string(window.name)
          }

        {:ok, original_response} = Client.visit(channel, request)

        request = %Protos.Browser.Window{
          name: Atom.to_string(window.name)
        }

        {:ok, refresh_response} = Client.refresh(channel, request)

        assert refresh_response.body != original_response.body
      end)
    end
  end

  describe "close" do
    test "an active window" do
      run_server(Server, fn port ->
        {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")
        {:ok, window} = Window.new()

        pid = Process.whereis(window.name)

        request = %Protos.Browser.Window{
          name: Atom.to_string(window.name)
        }

        {:ok, response} = Client.close(channel, request)

        assert response.name == ""

        refute Process.alive?(pid)
      end)
    end
  end
end

