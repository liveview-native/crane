defmodule LiveView.ViewTest do
  # use ExUnit.Case, async: true
  #
  # alias LiveView.{
  #   LiveSocket,
  #   View
  # }
  #
  # defp simulate_joined_view(el, live_socket) do
  #   {:ok, view} = LiveSocket.new_view(live_socket, el: el)
  #   {:ok, view} = stub_channel(view)
  #   {:ok, live_socket} = LiveSocket.update(live_socket, :roots, Map.put(live_socket.roots, view.id, view))
  #   # simulate connected
  #   View.on_join(view, %{rendered: %{s: [el: el.inner_html]}})
  # end
  #
  # defp tag_name({tag_name, _attrs, _children}),
  #   do: tag_name
  # def tag_name([{tag_name, _attrs, _children} | _tags]),
  #   do: tag_name
  #
  # describe "View + DOM" do
  #   test "update" do
  #     {:ok, live_socket} = LiveSocket.new(%Window{name: :test}, "/live")
  #     el = @live_view_dom
  #     update_diff = %{
  #       s: ["<h2>", "</h2>"],
  #       fingerprint: 123
  #     }
  #
  #     {:ok, view} = simulate_joined_view(el, live_socket)
  #     {:ok, view} = View.update(view, update_diff, [])
  #     assert tag_name(view.el) == "h2"
  #     assert Rendered.get(view.rendered) == update_diff
  #   end
  #
  #   test "apply_diff with empty title uses default if present" do # Changed "applyDiff"
  #     # Test content omitted
  #   end
  #
  #   test "push_with_reply" do # Changed "pushWithReply"
  #     # Test content omitted
  #   end
  #
  #   test "push_with_reply with update" do # Changed "pushWithReply"
  #     # Test content omitted
  #   end
  #
  #   test "push_event" do # Changed "pushEvent"
  #     # Test content omitted
  #   end
  #
  #   test "push_event as checkbox not checked" do # Changed "pushEvent"
  #     # Test content omitted
  #   end
  #
  #   test "push_event as checkbox when checked" do # Changed "pushEvent"
  #     # Test content omitted
  #   end
  #
  #   test "push_event as checkbox with value" do # Changed "pushEvent"
  #     # Test content omitted
  #   end
  #
  #   test "push_input" do # Changed "pushInput"
  #     # Test content omitted
  #   end
  #
  #   test "push_input with phx-value and JS command value" do # Changed "pushInput"
  #     # Test content omitted
  #   end
  #
  #   test "push_input with nameless input" do # Changed "pushInput"
  #     # Test content omitted
  #   end
  #
  #   test "get_forms_for_recovery" do # Changed "getFormsForRecovery"
  #     # Test content omitted
  #   end
  #
  #   describe "submit_form" do # Changed "submitForm"
  #     test "submits payload" do
  #       # Test content omitted
  #     end
  #
  #     test "payload includes phx-value and JS command value" do
  #       # Test content omitted
  #     end
  #
  #     test "payload includes submitter when name is provided" do
  #       # Test content omitted
  #     end
  #
  #     test "payload includes submitter when name is provided (submitter outside form)" do
  #       # Test content omitted
  #     end
  #
  #     test "payload does not include submitter when name is not provided" do
  #       # Test content omitted
  #     end
  #
  #     test "disables elements after submission" do
  #       # Test content omitted
  #     end
  #
  #     test "disables elements outside form" do
  #       # Test content omitted
  #     end
  #
  #     test "disables elements" do
  #       # Test content omitted
  #     end
  #   end
  #
  #   describe "phx-trigger-action" do # No change needed
  #     test "triggers external submit on updated DOM el" do
  #       # Test content omitted
  #     end
  #
  #     test "triggers external submit on added DOM el" do
  #       # Test content omitted
  #     end
  #   end
  #
  #   describe "phx-update" do # No change needed
  #     test "replace" do
  #       # Test content omitted
  #     end
  #
  #     test "append" do
  #       # Test content omitted
  #     end
  #
  #     test "prepend" do
  #       # Test content omitted
  #     end
  #
  #     test "ignore" do
  #       # Test content omitted
  #     end
  #   end
  # end
  #
  # describe "View" do # No change needed
  #   test "sets defaults" do
  #     # Test content omitted
  #   end
  #
  #   test "binding" do
  #     # Test content omitted
  #   end
  #
  #   test "get_session" do # Changed "getSession"
  #     # Test content omitted
  #   end
  #
  #   test "get_static" do # Changed "getStatic"
  #     # Test content omitted
  #   end
  #
  #   test "show_loader and hide_loader" do # Changed "showLoader" and "hideLoader"
  #     # Test content omitted
  #   end
  #
  #   test "display_error and hide_loader" do # Changed "displayError" and "hideLoader"
  #     # Test content omitted
  #   end
  #
  #   test "join" do
  #     # Test content omitted
  #   end
  #
  #   test "sends _track_static and _mounts on params" do # No change needed
  #     # Test content omitted
  #   end
  # end
  #
  # describe "View Hooks" do # No change needed
  #   test "phx-mounted" do # No change needed
  #     # Test content omitted
  #   end
  #
  #   test "hooks" do
  #     # Test content omitted
  #   end
  #
  #   test "create_hook" do # Changed "createHook"
  #     # Test content omitted
  #   end
  #
  #   test "view destroyed" do
  #     # Test content omitted
  #   end
  #
  #   test "view reconnected" do
  #     # Test content omitted
  #   end
  #
  #   test "dispatches uploads" do
  #     # Test content omitted
  #   end
  #
  #   test "dom hooks" do
  #     # Test content omitted
  #   end
  # end
  #
  # describe "View + Component" do # No change needed
  #   test "target_component_id" do # Changed "targetComponentID"
  #     # Test content omitted
  #   end
  #
  #   test "push_event" do # Changed "pushEvent" (already handled, but good to confirm consistency)
  #     # Test content omitted
  #   end
  #
  #   test "push_input" do # Changed "pushInput" (already handled)
  #     # Test content omitted
  #   end
  #
  #   test "adds auto ID to prevent teardown/re-add" do # Changed "auto ID"
  #     # Test content omitted
  #   end
  #
  #   test "respects nested components" do
  #     # Test content omitted
  #   end
  #
  #   test "destroys children when they are removed by an update" do
  #     # Test content omitted
  #   end
  #
  #   describe "undo_refs" do # Changed "undoRefs"
  #     test "restores phx specific attributes awaiting a ref" do
  #       # Test content omitted
  #     end
  #
  #     test "replaces any previous applied component" do
  #       # Test content omitted
  #     end
  #
  #     test "triggers before_update and updated hooks" do # Changed "beforeUpdate"
  #       # Test content omitted
  #     end
  #   end
  # end
  #
  # describe "DOM" do # No change needed
  #   test "merge_attrs attributes" do # Changed "mergeAttrs"
  #     # Test content omitted
  #   end
  #
  #   test "merge_attrs with properties" do # Changed "mergeAttrs"
  #     # Test content omitted
  #   end
  # end
end
