defmodule Crane.Phoenix.Layout do
  use Phoenix.Component

  def console(assigns) do
    ~H"""
      <body>
        <%= if Application.get_env(:live_debugger, :browser_features?) do %>
          <script id="live-debugger-scripts" src={Application.get_env(:live_debugger, :assets_url)}/>
        <% end %>
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

    /* Basic Reset & Body Styling */
    * {
        box-sizing: border-box;
        margin: 0;
        padding: 0;
    }

    html, body {
        height: 100%;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen-Sans, Ubuntu, Cantarell, "Helvetica Neue", sans-serif;
        font-size: 14px;
        background-color: #f0f0f0; /* Page background, mostly hidden */
        color: #333;
    }

    /* --- THEME VARIABLES --- */
    :root {
        /* Default: Dark Theme (with Dark Blue Tint) */
        --bg-deep-dark: #1a1f2c;       /* Darkest blue-grey */
        --bg-dark: #202533;           /* Main dark blue-grey */
        --bg-medium-dark: #2a3040;    /* Mid blue-grey */
        --bg-light-dark: #333a4d;     /* Lighter blue-grey */
        --bg-lighter-dark: #3a4155;   /* Lightest blue-grey bg */
        --bg-hover: #4f5870;           /* Hover blue-grey */
        --bg-highlight: rgba(74, 144, 226, 0.15); /* View tree hover */
        --bg-error-tint: rgba(255, 128, 125, 0.08);  /* Subtle red background for error node */
        --bg-error-highlight: rgba(255, 128, 125, 0.2); /* Red hover for error node */
        --bg-active-tab-high: var(--bg-lighter-dark); /* Active browser tab bg */
        --bg-active-tab-mid: var(--bg-medium-dark);   /* Active window tab bg */
        --bg-active-tab-low: var(--bg-dark);        /* Active content view tab bg */
        --bg-toolbar: var(--bg-light-dark);
        --bg-input: var(--bg-medium-dark);
        --bg-selected-row: #406088; /* Selection blue */

        --text-primary: #e8ecf5;       /* Main text */
        --text-secondary: #c5cde0;     /* Secondary text */
        --text-subtle: #a0a8c0;        /* Subtle text */
        --text-active: #ffffff;       /* Active elements */
        --text-placeholder: #78809a;   /* Input placeholders */
        --text-selected: #ffffff;      /* Text on selected row */

        --border-strong: #5a637c;       /* Stronger border */
        --border-medium: #4f5870;      /* Medium border */
        --border-light: #454c60;       /* Light border */
        --border-subtle: #3f4659;       /* Subtle border */
        --border-dotted: #4f5870;      /* Dotted lines */
        --border-input: var(--border-medium);
        --border-error: rgba(255, 107, 104, 0.6); /* Red border for error node */
        --tree-line-color: var(--border-dotted); /* Maybe unused now */

        --accent-border-high: #e0a030; /* Browser tab active border */
        --accent-border-mid: #4a90e2;  /* Window tab active border */
        --accent-border-low: #5cba7d;   /* Content view tab active border */
        --accent-text: var(--accent-border-mid); /* General accent color */

        --close-button-color: var(--text-subtle);
        --close-button-hover-bg: #707890;
        --close-button-hover-color: var(--text-active);

        --add-button-color: var(--text-subtle);
        --add-button-hover-bg: #5a637c;
        --add-button-hover-color: var(--text-active);

        --resizer-bg: var(--border-light);
        --resizer-border: var(--border-medium);
        --toggle-icon-color: var(--text-subtle);
        --collapse-indicator-color: var(--text-subtle); /* Kept if needed elsewhere */
        --icon-error-color: var(--log-error); /* Color for error icon in tree */

        /* Syntax/Log Colors */
        --dom-tag: #88abeb; /* Applied to summary text */
        --dom-attr: #c792ea; /* Applied to .node-attrs span */
        --dom-attr-name: #7abbff;
        --dom-attr-value: #dda378;
        --dom-value: #c3e88d; /* Cannot apply with current HTML */
        --log-error: #ff807d;
        --log-warn: #ffe080;
        --log-info: var(--text-primary);
        --log-debug: #88abeb;
        --log-timestamp: #78809a;

        /* Filter button colors */
        --filter-error-color: var(--log-error);
        --filter-warn-color: var(--log-warn);
        --filter-info-color: #a0a0ff;
        --filter-debug-color: var(--log-debug);
    }

    /* --- Light Theme Variable Overrides --- */
    /* This rule applies when the theme toggle checkbox is checked */
    .devtools-container.light-theme {
        --bg-deep-dark: #d0d0d0;
        --bg-dark: #e0e0e0;
        --bg-medium-dark: #f0f0f0;
        --bg-light-dark: #f8f8f8;
        --bg-lighter-dark: #ffffff;
        --bg-hover: #c8c8c8;
        --bg-highlight: rgba(74, 144, 226, 0.15);
        --bg-error-tint: rgba(209, 63, 60, 0.08);
        --bg-error-highlight: rgba(209, 63, 60, 0.18);
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
        --border-error: rgba(209, 63, 60, 0.6);
        --tree-line-color: var(--border-dotted);

        /* Accents remain the same */

        --close-button-color: var(--text-subtle);
        --close-button-hover-bg: #aaa;
        --close-button-hover-color: #000;

        --add-button-color: var(--text-subtle);
        --add-button-hover-bg: #ccc;
        --add-button-hover-color: #000;

        --resizer-bg: var(--border-light);
        --resizer-border: var(--border-medium);
        --toggle-icon-color: var(--text-subtle);
        --collapse-indicator-color: var(--text-subtle);
        --icon-error-color: var(--log-error);

        /* Syntax/Log Colors - Adjust for light bg */
        --dom-tag: #2170c1;
        --dom-attr: #9b29b3;
        --dom-value: #3f830d; /* Cannot apply */
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
        position: absolute; top: 10px; right: 15px; z-index: 100;
    }
    .theme-toggle-checkbox {
        display: none;
    }
    .theme-toggle-label {
        display: block; width: 50px; height: 26px;
        background-color: #555; /* Neutral dark grey for switch */
        border-radius: 13px; cursor: pointer; position: relative;
        transition: background-color 0.3s ease;
    }
    .toggle-indicator {
        display: block; width: 20px; height: 20px;
        background-color: #fff; border-radius: 50%;
        position: absolute; top: 3px; left: 4px;
        transition: left 0.3s ease;
    }
    /* Light Mode Switch Styles */
    .theme-toggle-checkbox:checked + .theme-toggle-label {
        background-color: var(--accent-border-mid); /* Use accent blue */
    }
    .theme-toggle-checkbox:checked + .theme-toggle-label .toggle-indicator {
        left: 26px;
    }


    /* --- LAYOUT & CORE STRUCTURE --- */
    .devtools-container {
        display: flex; flex-direction: column; height: 100vh;
        background-color: var(--bg-dark);
        color: var(--text-primary);
        border: 1px solid var(--border-light);
        overflow: hidden; /* Prevent scroll on main container */
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


    /* --- Tab Bars & Buttons --- */
    .tab-bar {
        display: flex; flex-shrink: 0; overflow-x: auto;
        border-bottom: 1px solid var(--border-medium);
        align-items: stretch; /* Key for consistent height */
    }

    .tab-button {
        position: relative; padding: 8px 15px; border: none;
        border-right: 1px solid var(--border-medium);
        background: none; color: var(--text-secondary); cursor: pointer;
        white-space: nowrap; font-size: 0.9em; line-height: 1.4; /* Consistent line height */
        transition: background-color 0.2s ease, color 0.2s ease;
        text-decoration: none; display: flex; align-items: center; justify-content: center;
    }
    /* Adjustments for specific tab levels */
    .browser-tab { font-size: 0.95em; padding-top: 10px; padding-bottom: 10px; }
    .window-tab { font-size: 0.92em; padding-top: 9px; padding-bottom: 9px; }
    .content-view-tab { font-size: 0.9em; padding-top: 8px; padding-bottom: 8px; }

    /* Remove border from last real tab before add */
    .tab-button:has(+ .add-tab),
    .tab-button:last-child:not(.add-tab) { border-right: none; }

    .tab-button:hover { background-color: var(--bg-hover); color: var(--text-active); }
    .tab-button.active { color: var(--text-active); font-weight: 500; position: relative; margin-bottom: -1px; /* Overlap border */}

    /* Active tab backgrounds & borders */
    .browser-tabs { background-color: var(--bg-deep-dark); padding-left: 5px; border-bottom-color: var(--border-strong); }
    .browser-tab.active { background-color: var(--bg-active-tab-high); border-bottom: 3px solid var(--accent-border-high); }

    .window-tabs { background-color: var(--bg-lighter-dark); padding-left: 10px; }
    .window-tab.active { background-color: var(--bg-active-tab-mid); border-bottom: 3px solid var(--accent-border-mid); }

    .content-view-tabs { background-color: var(--bg-light-dark); padding-left: 15px; }
    .content-view-tab.active { background-color: var(--bg-active-tab-low); border-bottom: 2px solid var(--accent-border-low); }

    /* Add Tab (+) */
    .add-tab {
        /* Inherit font-size, padding-top/bottom, line-height from sibling .tab-button */
        padding-left: 12px; padding-right: 12px; /* Specific horizontal padding */
        font-weight: bold; color: var(--add-button-color);
        border-left: 1px solid var(--border-medium); border-right: none;
        flex-shrink: 0; justify-content: center;
        transition: background-color 0.2s ease, color 0.2s ease;
    }
    .add-tab:hover { background-color: var(--add-button-hover-bg); color: var(--add-button-hover-color); }
    .add-tab.active { border-bottom: none; background-color: inherit; } /* Should not be active */

    /* Close Tab Button (X) */
    .close-tab-button {
        display: none; position: absolute; right: 4px; top: 50%; transform: translateY(-50%);
        font-size: 1.1em; line-height: 1; color: var(--close-button-color);
        padding: 2px 4px; border-radius: 50%; cursor: pointer; margin-left: 8px; z-index: 1;
        transition: background-color 0.2s ease, color 0.2s ease;
    }
    .close-tab-button:hover { background-color: var(--close-button-hover-bg); color: var(--close-button-hover-color); }
    .tab-button:hover > .close-tab-button { display: inline-block; }
    .tab-button:has(.close-tab-button) { padding-right: 28px; justify-content: space-between; } /* Make space for X */


    /* --- View Tree Pane --- */
    .view-tree-pane {
        flex-shrink: 0; /* Don't shrink by default */
        flex-basis: 40%; /* Example starting size, JS would adjust this */
        overflow: auto; /* Vertical scroll for tree */
        padding: 10px; border-bottom: 1px solid var(--border-light);
        font-family: Menlo, Monaco, Consolas, "Courier New", monospace;
        background-color: var(--bg-medium-dark); color: var(--text-primary);
        transition: background-color 0.3s ease, color 0.3s ease;
    }
    .view-tree-pane h3 {
        color: var(--text-subtle); margin-bottom: 10px; font-weight: normal;
        font-size: 1em; border-bottom: 1px solid var(--border-subtle);
        padding-bottom: 5px; flex-shrink: 0;
    }

    /* Styling for each <details> element representing a node */
    .view-tree-pane details {
        margin-left: 20px; /* Indentation for nested details */
        position: relative;
    }
    /* Reduce margin for top-level details */
    .view-tree-pane > details {
        margin-left: 0;
    }

    /* Styling for the clickable summary */
    .view-tree-pane summary.node { /* Targeting summary with class 'node' */
        display: flex; align-items: center; padding: 3px 5px;
        cursor: pointer; border-radius: 3px;
        transition: background-color 0.2s ease-out, border-left-color 0.2s ease-out;
        position: relative;
        border-left: 3px solid transparent; /* Space for potential error border */
        margin-left: -3px; /* Counteract border space */
        list-style: none; /* Hide default marker (important!) */
        color: var(--dom-tag); /* Color the whole summary like a tag by default */
        font-family: Menlo, Monaco, Consolas, "Courier New", monospace;
        font-size: 0.9em;
        line-height: 1.4;
        white-space: nowrap; /* Prevent summary text wrapping */
        overflow: hidden; /* Hide overflow */
        text-overflow: ellipsis; /* Add ... if summary is too long */
    }
    /* Also hide WebKit specific marker */
    .view-tree-pane summary.node::-webkit-details-marker { display: none; }
    .view-tree-pane summary.node:hover { background-color: var(--bg-highlight); }

    .view-tree-pane details .when-closed { display: inline; }
    .view-tree-pane details[open] .when-closed { display: none; }
    .view-tree-pane details .when-open { display: none; }
    .view-tree-pane details[open] .when-open { display: inline; }

    .view-tree-pane .text { font-style: italic; margin-left: 20px; color: white; }

    .view-tree-pane details .close-node { color: var(--dom-tag); }


    /* Styling for the attributes span inside summary */
    .view-tree-pane summary.node .node-attr {
        color: var(--dom-attr); /* Attribute color */
        margin-left: 0.4em; /* Space between tag and attributes */
        /* Values inside attrs span cannot be styled separately */
        white-space: normal; /* Allow attributes to wrap if necessary */
        overflow-wrap: break-word; /* Break long attribute strings */
        display: inline; /* Default display */
    }

    .view-tree-pane summary.node .node-attr .attr-name { color: var(--dom-attr-name); }
    .view-tree-pane summary.node .node-attr .attr-value { color: var(--dom-attr-value); }


    /* Custom Toggle Icon (Arrow) */
    .view-tree-pane summary.node::before {
        content: '►'; /* Collapsed state */
        display: inline-block;
        width: 16px; height: 16px; flex-shrink: 0;
        margin-right: 4px; text-align: center;
        transition: transform 0.15s ease-in-out;
        color: var(--toggle-icon-color);
        font-size: 0.8em;
        line-height: 16px; /* Center vertically */
        transform-origin: center center;
        margin-left: 3px; /* Base margin */
    }
    /* Change icon when details element is open */
    .view-tree-pane details[open] > summary.node::before {
        content: '▼';
    }
    /* Hide toggle icon if the details has no nested details (potential leaf node) */
    /* This selector is complex and might need adjustment based on actual leaf node structure */
    .view-tree-pane details:not(:has(> details)) > summary.node::before {
        visibility: hidden; /* Hide icon visually but keep space */
    }

    /* Error Icon */
    .error-icon {
        color: var(--icon-error-color);
        margin-right: 6px;
        margin-left: 3px; /* Space before icon */
        font-size: 0.9em;
        line-height: 1;
        flex-shrink: 0;
    }
    /* Adjust toggle icon margin if error icon is present */
    details.has-error > summary.node::before {
        margin-left: 0; /* Adjust base icon position */
    }

    /* Error State Styling (Applied to details.has-error) */
    details.has-error > summary.node {
        background-color: var(--bg-error-tint);
        border-left-color: var(--border-error);
    }
    details.has-error > summary.node:hover {
        background-color: var(--bg-error-highlight);
    }

    /* Styling for direct text content within <details> (after summary) */
    /* Example: text content like "Historic Peace Agreement Signed" */
    .view-tree-pane details > *:not(summary):not(details) {
        display: block;
        padding: 2px 5px 2px 27px; /* Indent similarly to nested summaries */
        color: var(--text-subtle);
        font-size: 0.9em;
        white-space: pre-wrap;
    }


    /* --- Pane Resizer --- */
    .pane-resizer {
        flex-shrink: 0; height: 3px; background-color: var(--resizer-bg);
        cursor: ns-resize; border-top: 1px solid var(--resizer-border); border-bottom: 1px solid #333;
    }


    /* --- Display Panel & Content Views --- */
    .display-panel {
        flex-grow: 1; overflow: hidden; display: flex; flex-direction: column;
        background-color: var(--bg-dark); color: var(--text-primary);
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

    /* Toolbar Base Styles */
    .toolbar {
        display: flex; align-items: center; padding: 5px 10px;
        background-color: var(--bg-toolbar); border-bottom: 1px solid var(--border-light);
        flex-shrink: 0; gap: 8px;
    }
    .toolbar-button, .toolbar-select, .toolbar-input, .toolbar-checkbox + label,
    .log-filter-button {
        font-size: 0.9em; padding: 3px 6px; background-color: var(--bg-input);
        color: var(--text-secondary); border: 1px solid var(--border-input);
        border-radius: 3px; cursor: pointer; transition: background-color 0.2s, color 0.2s, border-color 0.2s;
    }
    .toolbar-input, .log-filter-input { padding: 4px 6px; cursor: text; }
    .toolbar-input::placeholder, .log-filter-input::placeholder { color: var(--text-placeholder); }
    .toolbar-checkbox { margin-right: 4px; vertical-align: middle; }
    .toolbar-checkbox + label { padding: 0; border: none; background: none; vertical-align: middle; cursor: pointer; }
    .toolbar-separator { width: 1px; height: 16px; background-color: var(--border-medium); margin: 0 4px; }
    .toolbar-button:hover, .log-filter-button:hover { background-color: var(--bg-hover); color: var(--text-active); }
    .toolbar-button.active { background-color: var(--accent-text); color: white; border-color: var(--accent-text); }


    /* Console Log View */
    .console-log-view { /* Inherits .view-content */ }
    .log-filter-toolbar { /* Inherits .toolbar */ }
    .log-filter-input { width: 150px; }
    .log-filter-button.active {
        border-color: var(--accent-text);
        background-color: color-mix(in srgb, var(--accent-text) 20%, var(--bg-input));
        color: var(--text-active);
    }
    .log-filter-button.filter-error { color: var(--filter-error-color); }
    .log-filter-button.filter-warn { color: var(--filter-warn-color); }
    .log-filter-button.filter-info { color: var(--filter-info-color); }
    .log-filter-button.filter-debug { color: var(--filter-debug-color); }
    .log-filter-button.filter-all.active { background-color: var(--accent-text); color: white;}

    .log-output-area {
        flex-grow: 1; overflow: auto; padding: 10px 15px;
        font-family: Menlo, Monaco, Consolas, "Courier New", monospace;
        font-size: 0.9em; line-height: 1.5;
    }
    .log-output { white-space: pre-wrap; word-break: break-all; }
    .log-info { color: var(--log-info); }
    .log-warn { color: var(--log-warn); }
    .log-error { color: var(--log-error); }
    .log-debug { color: var(--log-debug); }
    .log-timestamp { color: var(--log-timestamp); margin-right: 10px;}


    /* Network Panel View */
    .network-panel-view { /* Inherits .view-content */ }
    .network-toolbar { /* Inherits .toolbar */ }
    .network-table-container { flex-grow: 1; overflow: auto; } /* Scrolls table */
    .network-table { width: 100%; border-collapse: collapse; font-size: 0.9em; table-layout: fixed; min-width: 800px; }
    .network-table th, .network-table td { padding: 6px 8px; border-bottom: 1px solid var(--border-subtle); text-align: left; vertical-align: middle; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .network-table thead th { background-color: var(--bg-toolbar); color: var(--text-subtle); position: sticky; top: 0; z-index: 1; border-bottom-width: 2px; border-bottom-color: var(--border-light); }
    .network-table th.sortable { cursor: pointer; }
    .network-table th.sortable:hover { color: var(--text-active); }
    .network-table th.sortable.asc::after, .network-table th.sortable.desc::after { content: ''; display: inline-block; width: 0; height: 0; border-left: 4px solid transparent; border-right: 4px solid transparent; margin-left: 5px; vertical-align: middle; }
    .network-table th.sortable.asc::after { border-bottom: 4px solid var(--text-subtle); }
    .network-table th.sortable.desc::after { border-top: 4px solid var(--text-subtle); }
    .network-table tbody tr.request-row:hover { background-color: var(--bg-hover); }
    .network-table tbody tr.request-row.selected { background-color: var(--bg-selected-row); color: var(--text-selected); }
    .network-table tbody tr.request-row.selected td { color: var(--text-selected); }
    .network-table .status-200 { color: var(--accent-border-low); }
    .network-table .status-304 { color: var(--text-subtle); }
    .network-table .status-401, .network-table .status-404 { color: var(--log-error); }
    /* Column Specific Widths & Styles (Example) */
    .network-table .col-name { width: 25%; }
    .network-table .col-status { width: 10%; }
    .network-table .col-type { width: 8%; }
    .network-table .col-initiator { width: 15%; }
    .network-table .col-size { width: 8%; text-align: right; }
    .network-table .col-time { width: 8%; text-align: right; }
    .network-table .col-waterfall { width: 20%; }
    /* Waterfall */
    .waterfall-track { width: 100%; height: 12px; background-color: color-mix(in srgb, var(--text-primary) 5%, transparent); position: relative; border-radius: 2px; overflow: hidden; }
    .waterfall-bar { position: absolute; top: 0; height: 100%; border-radius: 2px; opacity: 0.7; cursor: help; }
    .waterfall-bar.bar-timing { background-color: var(--accent-border-mid); }
    /* Network Summary */
    .network-summary { display: flex; align-items: center; padding: 6px 10px; background-color: var(--bg-toolbar); border-top: 1px solid var(--border-light); flex-shrink: 0; font-size: 0.85em; color: var(--text-secondary); gap: 8px; }
    .summary-separator { width: 1px; height: 12px; background-color: var(--border-medium); }


    /* Add styles for other .view-content sections (State, Source) as needed */
    </style>
    """
  end
end
