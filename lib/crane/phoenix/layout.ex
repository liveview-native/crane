defmodule Crane.Phoenix.Layout do
  use Phoenix.Component

  def window(assigns) do
    ~H"""
      <body>
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
                  background-color: #f0f0f0; /* Light background for contrast */
                  color: #333;
              }

              /* DevTools Container - Flex column layout */
              .devtools-container {
                  display: flex;
                  flex-direction: column;
                  height: 100vh; /* Full viewport height */
                  background-color: #242424; /* Dark background for the console itself */
                  color: #e0e0e0; /* Light text */
                  border: 1px solid #444;
              }

              /* Top Pane - DOM View */
              .top-pane {
                  flex: 1; /* Takes up available space */
                  overflow: auto; /* Add scroll if content overflows */
                  border-bottom: 1px solid #444; /* Separator line */
                  padding: 10px;
                  font-family: Menlo, Monaco, Consolas, "Courier New", monospace;
              }

              .top-pane h3 {
                  color: #aaa;
                  margin-bottom: 10px;
                  font-weight: normal;
                  font-size: 1em;
                  border-bottom: 1px solid #333;
                  padding-bottom: 5px;
              }

              /* Simple DOM tree styling */
              .dom-tree {
                  list-style: none;
                  padding-left: 0;
              }
              .dom-tree ul {
                  list-style: none;
                  padding-left: 20px; /* Indentation */
                  border-left: 1px dotted #555;
                  margin-left: 5px;
              }
              .dom-tree li {
                  margin: 3px 0;
              }
              .dom-tag {
                  color: #88abeb; /* HTML tag color */
              }
              .dom-attr {
                  color: #c792ea; /* Attribute name color */
              }
              .dom-value {
                  color: #c3e88d; /* Attribute value color */
              }


              /* Bottom Pane - Tabs and Content */
              .bottom-pane {
                  flex: 1; /* Takes up available space */
                  display: flex;
                  flex-direction: column;
                  overflow: hidden; /* Prevent content overflow from breaking layout */
              }

              /* Tab Bar */
              .tabs {
                  display: flex;
                  flex-shrink: 0; /* Prevent tabs from shrinking */
                  background-color: #333333; /* Slightly lighter tab background */
                  border-bottom: 1px solid #444; /* Separator */
                  overflow-x: auto; /* Allow horizontal scroll if too many tabs */
              }

              .tab-button {
                  padding: 8px 15px;
                  border: none;
                  background: none;
                  color: #ccc;
                  cursor: pointer; /* Indicate clickable (though not functional) */
                  border-right: 1px solid #444;
                  white-space: nowrap; /* Prevent wrapping */
                  font-size: 0.9em;
                  transition: background-color 0.2s ease;
              }

              .tab-button:hover {
                  background-color: #444;
              }

              /* Style for the 'active' tab */
              .tab-button.active {
                  background-color: #242424; /* Match content background */
                  color: #fff;
                  border-bottom: 2px solid #4a90e2; /* Blue indicator */
                  position: relative;
                  top: 1px; /* Align with bottom border removal */
                  margin-bottom: -1px; /* Overlap border */
              }

              /* Log Content Area */
              .log-content {
                  flex-grow: 1; /* Take remaining space in bottom pane */
                  padding: 10px;
                  overflow: auto; /* Allow vertical scroll */
                  font-family: Menlo, Monaco, Consolas, "Courier New", monospace;
                  font-size: 0.9em;
                  line-height: 1.5;
              }

              .log-line {
                  margin-bottom: 5px;
                  white-space: pre-wrap; /* Allow wrapping within lines */
                  word-break: break-all; /* Break long words/URLs */
              }

              .log-info { color: #e0e0e0; }
              .log-warn { color: #ffd700; } /* Yellow */
              .log-error { color: #ff6b68; } /* Red */
              .log-debug { color: #88abeb; } /* Blueish */

          </style>
          {@inner_content}
      </body>
    """
  end
end
