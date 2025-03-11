# defmodule Integration.UsageTest do
#   use GRPC.Integration.TestCase
#
#   test "various scenarios" do
#     {:ok, channel} = GRPC.Stub.connect("localhost:#{port}")
#
#     run_server(Server, fn port ->
#
#       headers = [
#         %Crane.Protos.Browser.Header{name: "Accept", value: "application/gameboy"}
#       ]
#
#       {:ok, browser} = Client.get(channel, %Protos.Browser{headers: headers})
#
#       {:ok, window} = 
#
#       Req.Test.stub(Window, fn(conn) ->
#         case Conn.request_url(conn) do
#           "https://dockyard.com/1" -> 
#             Conn.send_resp(conn, 200, "<Text>1</Text>")
#           "https://dockyard.com/2" -> 
#             Conn.send_resp(conn, 200, "<Text>2</Text>")
#           "https://dockyard.com/3" -> 
#             Conn.send_resp(conn, 200, "<Text>3</Text>")
#           "https://dockyard.com/4" -> 
#             Conn.send_resp(conn, 200, "<Text>4</Text>")
#           "https://dockyard.com/5" -> 
#             Conn.send_resp(conn, 200, "<Text>5</Text>")
#         end
#       end)
#
#       Req.Test.allow(Window, self(), pid_for(window))
#
#       Enum.each(headers, fn(header) ->
#         assert Enum.member?(browser.headers, header)
#       end)
#     end)
#   end
# end
