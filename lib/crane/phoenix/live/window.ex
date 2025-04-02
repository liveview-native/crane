defmodule Crane.Phoenix.Live.Window do
  use Phoenix.LiveView,
    layout: {Crane.Phoenix.Layout, :window}

  alias Crane.Browser.Window

  @tabs ~w{Logs Console Memory Performance Network}

  def mount(params, _session, socket) do
    {:ok, window} = Window.get(params["name"])

    {:ok, assign(socket, %{
      window: window,
      active_tab: "Logs",
      tabs: @tabs
    })}
  end

  def render(assigns) do
    ~H"""
      <div class="devtools-container">
          <div class="top-pane">
              <h3>Elements</h3>
              <ul class="dom-tree">
                  <li><span class="dom-tag">&lt;html&gt;</span>
                      <ul>
                          <li><span class="dom-tag">&lt;head&gt;</span>...</li>
                          <li><span class="dom-tag">&lt;body</span> <span class="dom-attr">class</span>=<span class="dom-value">"main"</span><span class="dom-tag">&gt;</span>
                              <ul>
                                  <li><span class="dom-tag">&lt;div</span> <span class="dom-attr">id</span>=<span class="dom-value">"app"</span><span class="dom-tag">&gt;</span>
                                      <ul>
                                          <li><span class="dom-tag">&lt;h1&gt;</span>Page Title<span class="dom-tag">&lt;/h1&gt;</span></li>
                                          <li><span class="dom-tag">&lt;p&gt;</span>Some content here.<span class="dom-tag">&lt;/p&gt;</span></li>
                                      </ul>
                                  </li>
                                  <li>&lt;!-- Comment Node --&gt;</li>
                                  <li><span class="dom-tag">&lt;script</span> <span class="dom-attr">src</span>=<span class="dom-value">"app.js"</span><span class="dom-tag">&gt;</span><span class="dom-tag">&lt;/script&gt;</span></li>
                              </ul>
                          </li>
                      </ul>
                  </li>
              </ul>
          </div>

          <div class="bottom-pane">
              <div class="tabs">
                <button :for={tab <- @tabs} phx-click="set_active_tab" phx-value-tab={tab} class={[
                  "tab-button",
                  active?(@active_tab, tab) && "active"
                ]}>{tab}</button>
              </div>
              <div class="log-content">
                  <div class="log-line log-info">[Info] Application initialized successfully. (main.js:10)</div>
                  <div class="log-line log-debug">[Debug] User ID: 12345 (auth.js:55)</div>
                  <div class="log-line log-warn">[Warn] API response time high: 1500ms (api.js:120)</div>
                  <div class="log-line log-info">User clicked button 'Submit'</div>
                  <div class="log-line log-error">[Error] Failed to fetch data: TypeError: Network request failed (api.js:150)</div>
                  <div class="log-line log-info">Another informational message.</div>
                  <div class="log-line log-error">[Error] Uncaught ReferenceError: variableNotDefined is not defined (app.js:25)</div>
              </div>
          </div>
      </div>
    """
  end

  defp active?(active_tab, active_tab),
    do: true
  defp active?(_active_tab, _other),
    do: false

  def handle_event("set_active_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end
end
