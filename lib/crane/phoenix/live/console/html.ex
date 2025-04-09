defmodule Crane.Phoenix.Live.Console.HTML do
  use Phoenix.Component

  alias Crane.{
    Browser,
    Browser.Window
  }

  def render(assigns) do
    ~H"""
    <div class={[
      "devtools-container",
      !@dark_theme && "light-theme"
    ]}>
      <.browser_panel
        :let={browser_state}
        browser_states={@browser_states}
        browsers={@browsers}
        active_browser={@active_browser}
      >
        <.window_panel :let={{window_state, active_window}} browser_state={browser_state} active_browser={@active_browser}>
          <.view_tree_panel active_window={active_window}/>
          <div class="pane-resizer"></div>
          <.bottom_section window_state={window_state}/>
        </.window_panel>
      </.browser_panel>
    </div>
    """
  end

  def browser_panel(assigns) do
    browser_state = 
      if assigns.active_browser do
        assigns.browser_states[assigns.active_browser.name]
      end
    assigns = assign(assigns, :browser_state, browser_state)

    ~H"""
    <div class="browser-tabs tab-bar">
      <button :for={browser <- @browsers} class={[
        "tab-button",
        "browser-tab",
        active?(@active_browser, browser) && "active"
      ]} phx-click="active_browser" phx-value-browser={browser.name}>
        <span class="close-tab-button" phx-click="close_browser" phx-value-browser={browser.name}>✕</span>
        {browser.name}
      </button>
      <button class="tab-button add-tab browser-add-tab" title="New Browser Session" phx-click="new_browser">
        +
      </button>
    </div>

    <div :if={@active_browser && @browser_state} class="browser-content-area">
      {render_slot(@inner_block, @browser_state)}
    </div>
    """
  end

  def window_panel(assigns) do
    window_state =
      if assigns.browser_state.active_window do
        get_in(assigns, [:browser_state, :window_states, assigns.browser_state.active_window.name])
      end
    windows = Browser.windows!(assigns.active_browser)
    assigns = assign(assigns,
      windows: windows,
      window_state: window_state)

    ~H"""
    <div class="window-tabs tab-bar">
      <button :for={window <- @windows} class={[
        "tab-button",
        "window-tab",
        active?(@browser_state.active_window, window) && "active"
      ]} phx-click="active_window" phx-value-window={window.name}>
        <span class="close-tab-button" phx-click="close_window" phx-value-window={window.name}>✕</span>
        {window.name}
      </button>
      <button class="tab-button add-tab window-add-tab" title="New Window Instance" phx-click="new_window">
        +
      </button>
    </div>
    <div :if={@browser_state.active_window && @window_state} class="window-content-area">
      {render_slot(@inner_block, {@window_state, @browser_state.active_window})}
    </div>
    """
  end

  def view_tree_panel(assigns) do
    ~H"""
    <div class="view-tree-pane">
      <h3>Elements</h3>
      <ul class="dom-tree">
        <li>
          <span class="dom-tag">&lt;body</span>
          <span class="dom-attr">id</span>=<span class="dom-value">"console-root"</span><span class="dom-tag">&gt;</span>...
        </li>
      </ul>
    </div>
    """
  end

  def bottom_section(assigns) do
    ~H"""
    <div class="bottom-section">
      <div class="content-view-tabs tab-bar">
        <button :for={tab <- ~w{Logs Network}} class={[
          "tab-button",
          "content-view-tab",
          active?(@window_state.active_tab, tab) && "active"
        ]} phx-click="set_active_tab" phx-value-tab={tab}>{tab}</button>
      </div>

      <div class="display-panel">
        <.display_panel type={@window_state.active_tab}/>
      </div>
    </div>
    """
  end

  def display_panel(%{type: "Logs"} = assigns) do
    ~H"""
    <div class="console-log-view view-content active">
      <div class="log-filter-toolbar">
        <input type="text" class="log-filter-input" placeholder="Filter logs..." />
        <div class="toolbar-separator"></div>
        <button class="log-filter-button filter-all active" title="All Logs">
          All
        </button>
        <button class="log-filter-button filter-error" title="Filter Errors">
          Errors
        </button>
        <button class="log-filter-button filter-warn" title="Filter Warnings">
          Warnings
        </button>
        <button class="log-filter-button filter-info" title="Filter Info">
          Info
        </button>
        <button class="log-filter-button filter-debug" title="Filter Debug">
          Debug
        </button>
        <div class="toolbar-separator"></div>
        <button class="toolbar-button" title="Clear Console">
          Clear
        </button>
      </div>
      <div class="log-output-area">
        <pre class="log-output">
          <span class="log-timestamp">[14:42:05]</span><span class="log-info">[Browser 1 > Console] Info: UI Initialized. Ready for interaction.</span>
          <span class="log-timestamp">[14:42:05]</span><span class="log-debug">[Browser 1 > Console] Debug: Theme set to dark by default. Location: Hingham, Massachusetts, United States. Current time: Monday, April 7, 2025 at 2:42 PM EDT</span>
          <span class="log-timestamp">[14:42:05]</span><span class="log-warn">[Browser 1 > Console] Warn: No network activity detected yet.</span>
        </pre>
      </div>
    </div>
    """
  end

  def display_panel(%{type: "Network"} = assigns) do
    ~H"""
    <div class="network-panel-view view-content active">
      <div class="network-toolbar">
        <button class="toolbar-button" title="Clear Log">
          Clear
        </button>
        <button class="toolbar-button filter-button active" title="Filter Requests">
          Filter
        </button>
        <input type="text" class="filter-input" placeholder="Filter requests..." />
        <div class="toolbar-separator"></div>
        <input type="checkbox" id="preserve-log-net" class="toolbar-checkbox" />
        <label for="preserve-log-net" title="Do not clear log on page navigation">Preserve log</label>
      </div>
      <div class="network-table-container">
        <table class="network-table">
          <thead>
            <tr>
              <th class="col-name sortable" title="Sort by Name">Name</th>
              <th class="col-status sortable" title="Sort by Status">Status</th>
              <th class="col-type sortable" title="Sort by Type">Type</th>
              <th class="col-initiator sortable" title="Sort by Initiator">
                Initiator
              </th>
              <th class="col-size sortable" title="Sort by Size">Size</th>
              <th class="col-time sortable" title="Sort by Time">Time</th>
              <th class="col-waterfall" title="Request Waterfall">Waterfall</th>
            </tr>
          </thead>
          <tbody>
            <tr class="request-row">
              <td class="col-name">GET /api/users</td>
              <td class="col-status status-200">200 OK</td>
              <td class="col-type type-fetch">fetch</td>
              <td class="col-initiator">app.js:150</td>
              <td class="col-size">15.3 KB</td>
              <td class="col-time">120 ms</td>
              <td class="col-waterfall">
                <div class="waterfall-track">
                  <div
                    class="waterfall-bar bar-timing"
                    style="margin-left: 5%; width: 20%;"
                    title="Waiting (TTFB): 20ms | Content Download: 100ms">
                  </div>
                </div>
              </td>
            </tr>
            <tr class="request-row selected">
              <td class="col-name">GET /assets/styles.css</td>
              <td class="col-status status-200">200 OK</td>
              <td class="col-type type-css">css</td>
              <td class="col-initiator">index.html:10</td>
              <td class="col-size">45.1 KB</td>
              <td class="col-time">85 ms</td>
              <td class="col-waterfall">
                <div class="waterfall-track">
                  <div
                    class="waterfall-bar bar-timing"
                    style="margin-left: 2%; width: 15%;"
                    title="Waiting (TTFB): 10ms | Content Download: 75ms">
                  </div>
                </div>
              </td>
            </tr>
            <tr class="request-row">
              <td class="col-name">GET /assets/logo.png</td>
              <td class="col-status status-200">200 OK</td>
              <td class="col-type type-img">png</td>
              <td class="col-initiator">styles.css:5</td>
              <td class="col-size">8.9 KB</td>
              <td class="col-time">55 ms</td>
              <td class="col-waterfall">
                <div class="waterfall-track">
                  <div
                    class="waterfall-bar bar-timing"
                    style="margin-left: 25%; width: 10%;"
                    title="Waiting (TTFB): 15ms | Content Download: 40ms">
                  </div>
                </div>
              </td>
            </tr>
            <tr class="request-row">
              <td class="col-name">POST /api/login</td>
              <td class="col-status status-401">401 Unauthorized</td>
              <td class="col-type type-fetch">fetch</td>
              <td class="col-initiator">login.js:30</td>
              <td class="col-size">512 B</td>
              <td class="col-time">210 ms</td>
              <td class="col-waterfall">
                <div class="waterfall-track">
                  <div
                    class="waterfall-bar bar-timing"
                    style="margin-left: 10%; width: 35%; background-color: var(--log-error);"
                    title="Waiting (TTFB): 200ms | Content Download: 10ms">
                  </div>
                </div>
              </td>
            </tr>
            <tr class="request-row">
              <td class="col-name">GET /assets/app.js</td>
              <td class="col-status status-304">304 Not Modified</td>
              <td class="col-type type-js">js</td>
              <td class="col-initiator">index.html:15</td>
              <td class="col-size">(disk cache)</td>
              <td class="col-time">5 ms</td>
              <td class="col-waterfall">
                <div class="waterfall-track">
                  <div
                    class="waterfall-bar bar-timing"
                    style="margin-left: 1%; width: 2%; background-color: #aaa;"
                    title="From Cache">
                  </div>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <div class="network-summary">...</div>
    </div>
    """
  end

  def display_panel(assigns) do
    ~H"""
    <div>Unknown type: {@type}</div>
    """
  end

  defp active?(%{name: name}, %{name: name}),
    do: true
  defp active?(resource, resource),
    do: true
  defp active?(_active_resource, _resource),
    do: false
end
