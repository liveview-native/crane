defmodule Crane.Phoenix.Live.Console do
  use Phoenix.LiveView

  alias Crane.{
    Browser,
    Browser.Window
  }

  def mount(_params, _session, socket) do
    {:ok, browser} = Browser.get()
    {:ok, windows} = Browser.windows(browser)

    Enum.each([browser | windows], fn(resource) ->
      Phoenix.PubSub.subscribe(PhoenixPlayground.PubSub, Atom.to_string(resource.name))
    end)

    {:ok, assign(socket, browser: browser, windows: windows)}
  end

  def render(assigns) do
    ~H"""
    <h1>Windows</h1>
    <ul>
      <li :for={window <- @windows}>
        <details>
          <summary><a href={"/window/#{window.name}"}>{window.name}</a></summary>
          <ul>
            <li>
              <details>
                <summary>History</summary>
                <ul>
                  <li :for={{{state, frame}, idx} <- Enum.with_index(window.history.stack)}>
                    <div><span :if={idx == window.history.index}>*</span>{idx} - {frame[:url]}</div>
                    <div>{inspect(state)}</div>
                  </li>
                </ul>
              </details>
            </li>
            <li>sockets: {Window.sockets!(window) |> length()}</li>
          </ul>
        </details>
      </li>
    </ul>
    """
  end

  def handle_info(:update, socket) do
    {:ok, browser} = Crane.Browser.get()
    {:ok, windows} = Crane.Browser.windows(browser)
    {:noreply, assign(socket, browser: browser, windows: windows)}
  end
end
