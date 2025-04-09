defmodule Crane.Phoenix.Layout do
  use Phoenix.Component

  def console(assigns) do
    ~H"""
      <body>
        <.style/>
          <div class="theme-switcher">
            <input type="checkbox" phx-click="toggle_theme" id="theme-toggle" class="theme-toggle-checkbox" checked={@dark_theme}/>
            <label for="theme-toggle" class="theme-toggle-label" title="Toggle Light/Dark Mode">
              <span class="toggle-indicator"></span>
            </label>
          </div>
        {@inner_content}
      </body>
    """
  end

  def style(assigns) do
    ~H"""
    <style>
    /* style.css */

    /* Basic Reset & Body Styling */
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    html,
    body {
      height: 100%;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
        Oxygen-Sans, Ubuntu, Cantarell, 'Helvetica Neue', sans-serif;
      font-size: 14px;
      background-color: #f0f0f0;
      color: #333;
    }

    /* --- THEME VARIABLES --- */
    :root {
      /* Default: Dark Theme (with Dark Blue Tint) */
      --bg-deep-dark: #1a1f2c; /* Darkest blue-grey (was #1a1a1a) */
      --bg-dark: #202533; /* Main dark blue-grey (was #202020) */
      --bg-medium-dark: #2a3040; /* Mid blue-grey (was #2a2a2a) */
      --bg-light-dark: #333a4d; /* Lighter blue-grey (was #333333) */
      --bg-lighter-dark: #3a4155; /* Lightest blue-grey bg (was #3a3a3a) */
      --bg-hover: #4f5870; /* Hover blue-grey (was #4f4f4f) */
      --bg-active-tab-high: var(--bg-lighter-dark);
      --bg-active-tab-mid: var(--bg-medium-dark);
      --bg-active-tab-low: var(--bg-dark);
      --bg-toolbar: var(--bg-light-dark);
      --bg-input: var(--bg-medium-dark);
      --bg-selected-row: #406088; /* Darker/Desaturated selection blue (was #4a6e9c) */

      --text-primary: #e8ecf5; /* Slightly brighter text for blue bg (was #e0e0e0) */
      --text-secondary: #c5cde0; /* Adjusted secondary text (was #ccc) */
      --text-subtle: #a0a8c0; /* Adjusted subtle text (was #aaa) */
      --text-active: #ffffff; /* Pure white for active elements (was #fff) */
      --text-placeholder: #78809a; /* Adjusted placeholder (was #888) */
      --text-selected: #ffffff; /* Text on selected row */

      --border-strong: #5a637c; /* Adjusted borders (was #666) */
      --border-medium: #4f5870; /* Adjusted borders (was #555) */
      --border-light: #454c60; /* Adjusted borders (was #444) */
      --border-subtle: #3f4659; /* Adjusted borders (was #383838) */
      --border-dotted: #4f5870; /* Adjusted borders (was #555) */
      --border-input: var(--border-medium);

      /* Accents remain the same for contrast */
      --accent-border-high: #e0a030;
      --accent-border-mid: #4a90e2;
      --accent-border-low: #5cba7d;
      --accent-text: var(--accent-border-mid);

      --close-button-color: var(--text-subtle);
      --close-button-hover-bg: #707890; /* Adjusted hover */
      --close-button-hover-color: var(--text-active);

      --add-button-color: var(--text-subtle);
      --add-button-hover-bg: #5a637c; /* Adjusted hover */
      --add-button-hover-color: var(--text-active);

      --resizer-bg: var(--border-light);
      --resizer-border: var(--border-medium);

      /* Syntax/Log Colors - Check contrast, adjust if needed */
      --dom-tag: #88abeb; /* Blues should still work */
      --dom-attr: #c792ea; /* Purples should still work */
      --dom-value: #c3e88d; /* Greens should still work */
      --log-error: #ff807d; /* Slightly adjusted red */
      --log-warn: #ffe080; /* Slightly adjusted yellow */
      --log-info: var(--text-primary);
      --log-debug: #88abeb;
      --log-timestamp: #78809a; /* Adjusted timestamp color */

      /* Filter button colors - Use original accents for clarity */
      --filter-error-color: var(--log-error);
      --filter-warn-color: var(--log-warn);
      --filter-info-color: #a0a0ff;
      --filter-debug-color: var(--log-debug);
    }

    /* --- Light Theme Variable Overrides --- */
    /* Applied via checkbox hack */
    .light-theme {
      /* Use class instead of ID selector for flexibility */
      --bg-deep-dark: #d0d0d0;
      --bg-dark: #e0e0e0;
      --bg-medium-dark: #f0f0f0;
      --bg-light-dark: #f8f8f8;
      --bg-lighter-dark: #ffffff;
      --bg-hover: #c8c8c8;
      --bg-active-tab-high: var(--bg-lighter-dark);
      --bg-active-tab-mid: var(--bg-medium-dark);
      --bg-active-tab-low: var(--bg-dark);
      --bg-toolbar: var(--bg-light-dark);
      --bg-input: var(--bg-lighter-dark);
      --bg-selected-row: #aeccec;

      --text-primary: #222;
      --text-secondary: #444;
      --text-subtle: #666;
      --text-active: #000;
      --text-placeholder: #999;
      --text-selected: #000;

      --border-strong: #aaa;
      --border-medium: #bbb;
      --border-light: #ccc;
      --border-subtle: #ddd;
      --border-dotted: #bbb;
      --border-input: var(--border-medium);

      /* Accent borders remain the same color */

      --close-button-color: var(--text-subtle);
      --close-button-hover-bg: #aaa;
      --close-button-hover-color: #000;

      --add-button-color: var(--text-subtle);
      --add-button-hover-bg: #ccc;
      --add-button-hover-color: #000;

      --resizer-bg: var(--border-light);
      --resizer-border: var(--border-medium);

      /* Syntax/Log Colors - Adjust for light bg */
      --dom-tag: #2170c1;
      --dom-attr: #9b29b3;
      --dom-value: #3f830d;
      --log-error: #d13f3c;
      --log-warn: #b8860b;
      --log-info: var(--text-primary);
      --log-debug: #2170c1;
      --log-timestamp: #777;

      /* Filter button colors */
      --filter-error-color: var(--log-error);
      --filter-warn-color: var(--log-warn);
      --filter-info-color: #3b3bff;
      --filter-debug-color: var(--log-debug);
    }

    /* --- THEME SWITCHER --- */
    .theme-switcher {
      position: absolute;
      top: 10px;
      right: 15px;
      z-index: 100;
    }
    .theme-toggle-checkbox {
      display: none;
    }
    .theme-toggle-label {
      display: block;
      width: 50px;
      height: 26px;
      background-color: #555;
      border-radius: 13px;
      cursor: pointer;
      position: relative;
      transition: background-color 0.3s ease;
    }
    .toggle-indicator {
      display: block;
      width: 20px;
      height: 20px;
      background-color: #fff;
      border-radius: 50%;
      position: absolute;
      top: 3px;
      left: 4px;
      transition: left 0.3s ease;
    }
    .theme-toggle-checkbox:checked + .theme-toggle-label {
      background-color: #4a90e2;
    }
    .theme-toggle-checkbox:checked + .theme-toggle-label .toggle-indicator {
      left: 26px;
    }
    /* Apply light theme class to container */
    #theme-toggle:checked ~ .devtools-container {
      /* This applies the variable overrides */
      --bg-deep-dark: #d0d0d0;
      --bg-dark: #e0e0e0;
      --bg-medium-dark: #f0f0f0;
      --bg-light-dark: #f8f8f8;
      --bg-lighter-dark: #ffffff;
      --bg-hover: #c8c8c8;
      --bg-active-tab-high: var(--bg-lighter-dark);
      --bg-active-tab-mid: var(--bg-medium-dark);
      --bg-active-tab-low: var(--bg-dark);
      --bg-toolbar: var(--bg-light-dark);
      --bg-input: var(--bg-lighter-dark);
      --bg-selected-row: #aeccec;

      --text-primary: #222;
      --text-secondary: #444;
      --text-subtle: #666;
      --text-active: #000;
      --text-placeholder: #999;
      --text-selected: #000;

      --border-strong: #aaa;
      --border-medium: #bbb;
      --border-light: #ccc;
      --border-subtle: #ddd;
      --border-dotted: #bbb;
      --border-input: var(--border-medium);

      --close-button-color: var(--text-subtle);
      --close-button-hover-bg: #aaa;
      --close-button-hover-color: #000;

      --add-button-color: var(--text-subtle);
      --add-button-hover-bg: #ccc;
      --add-button-hover-color: #000;

      --resizer-bg: var(--border-light);
      --resizer-border: var(--border-medium);

      --dom-tag: #2170c1;
      --dom-attr: #9b29b3;
      --dom-value: #3f830d;
      --log-error: #d13f3c;
      --log-warn: #b8860b;
      --log-info: var(--text-primary);
      --log-debug: #2170c1;
      --log-timestamp: #777;

      --filter-error-color: var(--log-error);
      --filter-warn-color: var(--log-warn);
      --filter-info-color: #3b3bff;
      --filter-debug-color: var(--log-debug);
    }

    /* --- LAYOUT & CORE STRUCTURE --- */
    .devtools-container {
      display: flex;
      flex-direction: column;
      height: 100vh;
      background-color: var(--bg-dark);
      color: var(--text-primary);
      border: 1px solid var(--border-light);
      overflow: hidden;
      transition: background-color 0.3s ease, color 0.3s ease;
    }

    .browser-content-area,
    .window-content-area,
    .bottom-section {
      display: flex;
      flex-direction: column;
      flex-grow: 1;
      overflow: hidden; /* Contain children, prevent parent scroll */
    }
    .content-area {
      /* Keep compatibility maybe? Replaced by window-content-area */
      flex-grow: 1;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      background-color: var(--bg-medium-dark);
    }

    /* --- Tab Bars & Buttons --- */
    .tab-bar {
      display: flex;
      flex-shrink: 0;
      overflow-x: auto;
      border-bottom: 1px solid var(--border-medium);
      align-items: stretch; /* Key for consistent height */
    }

    .tab-button {
      position: relative;
      padding: 8px 15px;
      border: none;
      border-right: 1px solid var(--border-medium);
      background: none;
      color: var(--text-secondary);
      cursor: pointer;
      white-space: nowrap;
      font-size: 0.9em;
      line-height: 1.4; /* Consistent line height */
      transition: background-color 0.2s ease, color 0.2s ease;
      text-decoration: none;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    /* Adjustments for specific tab levels */
    .browser-tab {
      font-size: 0.95em;
      padding-top: 10px;
      padding-bottom: 10px;
    }
    .window-tab {
      font-size: 0.92em;
      padding-top: 9px;
      padding-bottom: 9px;
    }
    .content-view-tab {
      font-size: 0.9em;
      padding-top: 8px;
      padding-bottom: 8px;
    }

    /* Remove border from last real tab */
    .tab-button:has(+ .add-tab),
    .tab-button:last-child:not(.add-tab) {
      border-right: none;
    }

    .tab-button:hover {
      background-color: var(--bg-hover);
      color: var(--text-active);
    }
    .tab-button.active {
      color: var(--text-active);
      font-weight: 500;
      position: relative;
      margin-bottom: -1px; /* Overlap border */
    }

    /* Active tab backgrounds & borders */
    .browser-tab.active {
      background-color: var(--bg-active-tab-high);
      border-bottom: 3px solid var(--accent-border-high);
    }
    .window-tab.active {
      background-color: var(--bg-active-tab-mid);
      border-bottom: 3px solid var(--accent-border-mid);
    }
    .content-view-tab.active {
      background-color: var(--bg-active-tab-low);
      border-bottom: 2px solid var(--accent-border-low);
    }

    /* Add Tab (+) */
    .add-tab {
      /* Inherit font-size, padding-top/bottom, line-height from sibling .tab-button in its bar */
      padding-left: 12px;
      padding-right: 12px; /* Specific horizontal padding */
      font-weight: bold;
      color: var(--add-button-color);
      border-left: 1px solid var(--border-medium);
      border-right: none;
      flex-shrink: 0;
      justify-content: center;
      transition: background-color 0.2s ease, color 0.2s ease;
    }
    .add-tab:hover {
      background-color: var(--add-button-hover-bg);
      color: var(--add-button-hover-color);
    }
    .add-tab.active {
      border-bottom: none;
      background-color: inherit;
    } /* Should not be active */

    /* Close Tab Button (X) */
    .close-tab-button {
      /* Styles remain similar */
      display: none;
      position: absolute;
      right: 4px;
      top: 50%;
      transform: translateY(-50%);
      font-size: 1.1em;
      line-height: 1;
      color: var(--close-button-color);
      padding: 2px 4px;
      border-radius: 50%;
      cursor: pointer;
      margin-left: 8px;
      z-index: 1;
      transition: background-color 0.2s ease, color 0.2s ease;
    }
    .close-tab-button:hover {
      background-color: var(--close-button-hover-bg);
      color: var(--close-button-hover-color);
    }
    .tab-button:hover > .close-tab-button {
      display: inline-block;
    }
    .tab-button:has(.close-tab-button) {
      padding-right: 28px;
      justify-content: space-between;
    }

    /* --- Specific Pane Styling --- */

    /* Browser/Window Tab Bar Backgrounds */
    .browser-tabs {
      background-color: var(--bg-deep-dark);
      padding-left: 5px;
      border-bottom-color: var(--border-strong);
    }
    .window-tabs {
      background-color: var(--bg-lighter-dark);
      padding-left: 10px;
    }
    .content-view-tabs {
      background-color: var(--bg-light-dark);
      padding-left: 15px;
    }

    /* View Tree Pane */
    .view-tree-pane {
      flex-shrink: 0; /* Don't shrink by default, rely on flex-basis/height */
      flex-basis: 40%; /* Example starting size, resizer adjusts this */
      overflow: auto; /* Vertical scroll for tree */
      padding: 10px;
      border-bottom: 1px solid var(--border-light);
      font-family: Menlo, Monaco, Consolas, 'Courier New', monospace;
      background-color: var(--bg-medium-dark);
      color: var(--text-primary);
      transition: background-color 0.3s ease, color 0.3s ease;
    }
    .view-tree-pane h3 {
      /* Styles remain similar */
      color: var(--text-subtle);
      margin-bottom: 10px;
      font-weight: normal;
      font-size: 1em;
      border-bottom: 1px solid var(--border-subtle);
      padding-bottom: 5px;
    }
    .dom-tree {
      list-style: none;
      padding-left: 0;
      font-size: 0.9em;
    }
    .dom-tree ul {
      list-style: none;
      padding-left: 20px;
      border-left: 1px dotted var(--border-dotted);
      margin-left: 5px;
    }
    .dom-tree li {
      margin: 3px 0;
    }
    .dom-tag {
      color: var(--dom-tag);
    }
    .dom-attr {
      color: var(--dom-attr);
    }
    .dom-value {
      color: var(--dom-value);
    }

    /* Resizer */
    .pane-resizer {
      flex-shrink: 0;
      height: 3px;
      background-color: var(--resizer-bg);
      cursor: ns-resize;
      border-top: 1px solid var(--resizer-border);
      border-bottom: 1px solid #333;
    }

    /* --- Display Panel & Content Views --- */
    .display-panel {
      flex-grow: 1; /* Takes space below content-view-tabs */
      overflow: hidden; /* Children handle their own scroll */
      display: flex; /* Prepare for switching content */
      flex-direction: column; /* Default stacking */
      background-color: var(--bg-dark);
      color: var(--text-primary);
      transition: background-color 0.3s ease, color 0.3s ease;
    }

    /* Hide all specific views by default */
    .display-panel .view-content {
      display: none;
      flex-direction: column;
      flex-grow: 1;
      overflow: hidden; /* Contain children */
    }
    /* Show the active view */
    .display-panel .view-content.active {
      display: flex;
    }

    /* Toolbar Base Styles (used by Log Filter & Network) */
    .toolbar {
      display: flex;
      align-items: center;
      padding: 5px 10px;
      background-color: var(--bg-toolbar);
      border-bottom: 1px solid var(--border-light);
      flex-shrink: 0;
      gap: 8px;
    }
    .toolbar-button,
    .toolbar-select,
    .toolbar-input,
    .toolbar-checkbox + label,
    .log-filter-button {
      /* Shared button styles */
      font-size: 0.9em;
      padding: 3px 6px;
      background-color: var(--bg-input);
      color: var(--text-secondary);
      border: 1px solid var(--border-input);
      border-radius: 3px;
      cursor: pointer;
    }
    .toolbar-input,
    .log-filter-input {
      padding: 4px 6px;
      cursor: text;
    }
    .toolbar-input::placeholder,
    .log-filter-input::placeholder {
      color: var(--text-placeholder);
    }
    .toolbar-checkbox {
      margin-right: 4px;
      vertical-align: middle;
    }
    .toolbar-checkbox + label {
      padding: 0;
      border: none;
      background: none;
      vertical-align: middle;
      cursor: pointer;
    }
    .toolbar-separator {
      width: 1px;
      height: 16px;
      background-color: var(--border-medium);
      margin: 0 4px;
    }
    .toolbar-button:hover,
    .log-filter-button:hover {
      background-color: var(--bg-hover);
      color: var(--text-active);
    }
    .toolbar-button.active {
      background-color: var(--accent-text);
      color: white;
      border-color: var(--accent-text);
    }

    /* Console Log View */
    .log-filter-toolbar {
      /* Inherits .toolbar */
    }
    .log-filter-input {
      width: 150px; /* Example width */
    }
    .log-filter-button {
      /* Specific filter button styling */
    }
    .log-filter-button.active {
      border-color: var(--accent-text);
      background-color: color-mix(
        in srgb,
        var(--accent-text) 20%,
        var(--bg-input)
      ); /* Slightly tinted bg */
      color: var(--text-active);
    }
    /* Color coding filter buttons */
    .log-filter-button.filter-error {
      color: var(--filter-error-color);
    }
    .log-filter-button.filter-warn {
      color: var(--filter-warn-color);
    }
    .log-filter-button.filter-info {
      color: var(--filter-info-color);
    }
    .log-filter-button.filter-debug {
      color: var(--filter-debug-color);
    }
    .log-filter-button.filter-all.active {
      background-color: var(--accent-text);
      color: white;
    } /* All active is stronger */

    .log-output-area {
      flex-grow: 1;
      overflow: auto; /* Scroll the log lines */
      padding: 10px 15px;
      font-family: Menlo, Monaco, Consolas, 'Courier New', monospace;
      font-size: 0.9em;
      line-height: 1.5;
    }
    .log-output {
      white-space: pre-wrap;
      word-break: break-all;
    }
    .log-info {
      color: var(--log-info);
    }
    .log-warn {
      color: var(--log-warn);
    }
    .log-error {
      color: var(--log-error);
    }
    .log-debug {
      color: var(--log-debug);
    }
    .log-timestamp {
      color: var(--log-timestamp);
      margin-right: 10px;
    }

    /* Network Panel View */
    .network-panel-view {
      /* Styles defined previously, ensure variables are used */
    }
    .network-toolbar {
      /* Inherits .toolbar */
    }
    .network-table-container {
      flex-grow: 1;
      overflow: auto;
    }
    .network-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.9em;
      table-layout: fixed;
      min-width: 800px;
    }
    .network-table th,
    .network-table td {
      padding: 6px 8px;
      border-bottom: 1px solid var(--border-subtle);
      text-align: left;
      vertical-align: middle;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .network-table thead th {
      background-color: var(--bg-toolbar);
      color: var(--text-subtle);
      position: sticky;
      top: 0;
      z-index: 1;
      border-bottom-width: 2px;
      border-bottom-color: var(--border-light);
    }
    .network-table th.sortable {
      cursor: pointer;
    }
    .network-table th.sortable:hover {
      color: var(--text-active);
    }
    /* Sort indicators */
    .network-table th.sortable.asc::after,
    .network-table th.sortable.desc::after {
      content: '';
      display: inline-block;
      width: 0;
      height: 0;
      border-left: 4px solid transparent;
      border-right: 4px solid transparent;
      margin-left: 5px;
      vertical-align: middle;
    }
    .network-table th.sortable.asc::after {
      border-bottom: 4px solid var(--text-subtle);
    }
    .network-table th.sortable.desc::after {
      border-top: 4px solid var(--text-subtle);
    }
    /* Rows */
    .network-table tbody tr.request-row:hover {
      background-color: var(--bg-hover);
    }
    .network-table tbody tr.request-row.selected {
      background-color: var(--bg-selected-row);
      color: var(--text-selected);
    }
    .network-table tbody tr.request-row.selected td {
      color: var(--text-selected);
    } /* Ensure td text inherits */
    /* Status colors */
    .network-table .status-200 {
      color: var(--accent-border-low);
    }
    .network-table .status-304 {
      color: var(--text-subtle);
    }
    .network-table .status-401,
    .network-table .status-404 {
      color: var(--log-error);
    }
    /* Waterfall */
    .waterfall-track {
      width: 100%;
      height: 12px;
      background-color: color-mix(in srgb, var(--text-primary) 5%, transparent);
      position: relative;
      border-radius: 2px;
    }
    .waterfall-bar {
      position: absolute;
      top: 0;
      height: 100%;
      border-radius: 2px;
      opacity: 0.7;
      cursor: help;
    }
    .waterfall-bar.bar-timing {
      background-color: var(--accent-border-mid);
    }
    /* Summary */
    .network-summary {
      display: flex;
      align-items: center;
      padding: 6px 10px;
      background-color: var(--bg-toolbar);
      border-top: 1px solid var(--border-light);
      flex-shrink: 0;
      font-size: 0.85em;
      color: var(--text-secondary);
      gap: 8px;
    }
    .summary-separator {
      width: 1px;
      height: 12px;
      background-color: var(--border-medium);
    }

    /* Add more styles for State, Source views as needed */

    </style>
    """
  end
end
