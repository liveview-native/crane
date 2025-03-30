defmodule Crane.Phoenix.Live.Console do
  use Phoenix.LiveView

  @topic "logger"

  def mount(_params, _session, socket) do
    {:ok, windows} = Crane.Browser.windows(%Crane.Browser{})
    IO.inspect(windows)
    {:ok, assign(socket, :windows, windows)}
  end

  def render(assigns) do
    ~H"""
    <h1>Windows</h1>
    <ul>
      <li :for={{window_name, window} <- @windows}>
        <details>
          <summary><a href={"/window/#{window_name}"}>{window_name}</a></summary>
          <ul>
            <li>
              <details>
                <summary>History</summary>
                <ul>
                  <li :for={{frame, idx} <- Enum.with_index(window.history.stack)}>
                    <span :if={idx == window.history.index}>*</span>{idx} - {frame.url}
                  </li>
                </ul>
              </details>
            </li>
            <li>sockets: {Map.keys(window.sockets) |> length()}</li>
          </ul>
        </details>
      </li>
    </ul>
    """
  end

  def handle_info(:update, socket) do
    {:ok, windows} = Crane.Browser.windows(%Crane.Browser{})
    {:noreply, assign(socket, :windows, windows)}
  end
end
