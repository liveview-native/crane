defmodule LiveView.ModifyRootTest do
  use ExUnit.Case, async: true
  
  alias LiveView.View.Rendered
  
  describe "modify_root/3 stripping comments" do
    test "starting comments" do
      # starting comments
      markup = """
      <!-- start -->
      <!-- start2 -->
      <Group class="px-51"><!-- MENU --><Group id="menu">MENU</Group></div>
      """
      
      {stripped_markup, comment_before, comment_after} = Rendered.modify_root(markup, %{})
      assert stripped_markup == "<Group class=\"px-51\"><!-- MENU --><Group id=\"menu\">MENU</Group></div>"
      assert comment_before == """
      <!-- start -->
      <!-- start2 -->
      """
      assert comment_after == "\n"
    end

    test "ending comments" do
      markup = """
      <Group class="px-52"><!-- MENU --><Group id="menu">MENU</Group></div>
      <!-- ending -->
      """
      
      {stripped_markup, comment_before, comment_after} = Rendered.modify_root(markup, %{})
      assert stripped_markup == "<Group class=\"px-52\"><!-- MENU --><Group id=\"menu\">MENU</Group></div>"
      assert comment_before == ""
      assert comment_after == """
      <!-- ending -->
      """
    end

    test "starting and ending comments" do
      markup = """
      <!-- starting -->
      <Group class="px-53"><!-- MENU --><Group id="menu">MENU</Group></div>
      <!-- ending -->
      """
      
      {stripped_markup, comment_before, comment_after} = Rendered.modify_root(markup, %{})
      assert stripped_markup == "<Group class=\"px-53\"><!-- MENU --><Group id=\"menu\">MENU</Group></div>"
      assert comment_before == """
      <!-- starting -->
      """
      assert comment_after == """
      <!-- ending -->
      """
    end

    test "merges new attrs" do
      markup = """
      <Group class="px-5"><Group id="menu">MENU</Group></div>
      """
      
      {result, _, _} = Rendered.modify_root(markup, %{id: 123})
      assert result == "<Group id=\"123\" class=\"px-5\"><Group id=\"menu\">MENU</Group></div>"
      
      {result, _, _} = Rendered.modify_root(markup, %{id: 123, another: ""})
      assert result == "<Group id=\"123\" another=\"\" class=\"px-5\"><Group id=\"menu\">MENU</Group></div>"
      
      # clearing innermarkup
      {result, _, _} = Rendered.modify_root(markup, %{id: 123, another: ""}, true)
      assert result == "<Group id=\"123\" another=\"\"></Group>"
      
      # self closing
      self_close = """
      <Spacer class="px-5"/>
      """
      
      {result, _, _} = Rendered.modify_root(self_close, %{id: 123, another: ""})
      assert result == "<Spacer id=\"123\" another=\"\" class=\"px-5\"/>"
    end

    test "mixed whitespace" do
      markup = """
      <Group
      \tclass="px-5"><Group id="menu">MENU</Group></div>
      """
      
      {result, _, _} = Rendered.modify_root(markup, %{id: 123})
      assert result == """
      <Group id="123"
      \tclass="px-5"><Group id="menu">MENU</Group></div>
      """ |> String.trim()
      
      {result, _, _} = Rendered.modify_root(markup, %{id: 123, another: ""})
      assert result == """
      <Group id="123" another=""
      \tclass="px-5"><Group id="menu">MENU</Group></div>
      """ |> String.trim()
      
      # clearing innermarkup
      {result, _, _} = Rendered.modify_root(markup, %{id: 123, another: ""}, true)
      assert result == "<Group id=\"123\" another=\"\"></Group>"
    end

    test "self closed" do
      markup = "<Spacer\t\r\nclass=\"px-5\"/>"
      # length: 23, tagname: 7, close_at: 22
      {result, _, _} = Rendered.modify_root(markup, %{id: 123, another: ""})
      assert result == "<Spacer id=\"123\" another=\"\"\t\r\nclass=\"px-5\"/>"

      markup = "<Spacer class=\"text-sm\"/>"
      # length: 25, tagname: 7, close_at: 24
      
      {result, _, _} = Rendered.modify_root(markup, %{id: 123})
      assert result == "<Spacer id=\"123\" class=\"text-sm\"/>"

      markup = "<img/>"
      {result, _, _} = Rendered.modify_root(markup, %{id: 123})
      assert result == "<img id=\"123\"/>"

      markup = "<img>"
      {result, _, _} = Rendered.modify_root(markup, %{id: 123})
      assert result == "<img id=\"123\">"

      markup = "<!-- before --><!-- <> --><Spacer class=\"text-sm\"/><!-- after -->"
      {result, comment_before, comment_after} = Rendered.modify_root(markup, %{id: 123})
      assert result == "<Spacer id=\"123\" class=\"text-sm\"/>"
      assert comment_before == "<!-- before --><!-- <> -->"
      assert comment_after == "<!-- after -->"

      # unclosed self closed
      markup = "<img class=\"px-5\">"
      {result, _, _} = Rendered.modify_root(markup, %{id: 123})
      assert result == "<img id=\"123\" class=\"px-5\">"

      markup = "<!-- <before> --><img class=\"px-5\"><!-- <after> --><!-- <after2> -->"
      {result, comment_before, comment_after} = Rendered.modify_root(markup, %{id: 123})
      assert result == "<img id=\"123\" class=\"px-5\">"
      assert comment_before == "<!-- <before> -->"
      assert comment_after == "<!-- <after> --><!-- <after2> -->"
    end

    test "does not extract id from inner element" do
      markup = "<Group>\n  <Group id=\"verify-payment-data-component\" data-phx-id=\"phx-F6AZf4FwSR4R50pB-39\" data-phx-skip></Group>\n</div>"
      attrs = %{
        "data-phx-id" => "c3-phx-F6AZf4FwSR4R50pB",
        "data-phx-component" => 3,
        "data-phx-skip" => true
      }

      {stripped_markup, _comment_before, _comment_after} = Rendered.modify_root(markup, attrs, true)

      assert stripped_markup == "<Group data-phx-id=\"c3-phx-F6AZf4FwSR4R50pB\" data-phx-component=\"3\" data-phx-skip></Group>"
    end
  end
end
