defmodule LiveView.RenderedTest do
  use ExUnit.Case, async: true
  
  alias LiveView.View.Rendered
  
  use LiveView.Constants, [
    :components,
    :dynamics,
    :static,
    :templates
  ]

  @simple_diff1 %{
      0 => "cooling",
      1 => "cooling",
      2 => "07:15:03 PM",
      @static => [
        "<div class=\"thermostat\">\n  <div class=\"bar ",
        "\">\n    <a href=\"#\" phx-click=\"toggle-mode\">",
        "</a>\n    <span>",
        "</span>\n  </div>\n</div>\n",
      ],
      :r => 1
    }

  @simple_diff2 %{
      2 => "07:15:04 PM"
    }

  @simple_diff_result %{
      0 => "cooling",
      1 => "cooling",
      2 => "07:15:04 PM",
      @static => [
        "<div class=\"thermostat\">\n  <div class=\"bar ",
        "\">\n    <a href=\"#\" phx-click=\"toggle-mode\">",
        "</a>\n    <span>",
        "</span>\n  </div>\n</div>\n",
      ],
      :r => 1
    }

  @deep_diff1 %{
      0 => %{
        0 => %{
          @dynamics => [["user1058", "1"], ["user99", "1"]],
          @static => ["        <tr>\n          <td>", " (", ")</td>\n        </tr>\n"],
          :r => 1
        },
        @static => [
          "  <table>\n    <thead>\n      <tr>\n        <th>Username</th>\n        <th></th>\n      </tr>\n    </thead>\n    <tbody>\n",
          "    </tbody>\n  </table>\n",
        ],
        :r => 1
      },
      1 => %{
        @dynamics => [
          [
            "asdf_asdf",
            "asdf@asdf.com",
            "123-456-7890",
            "<a href=\"/users/1\">Show</a>",
            "<a href=\"/users/1/edit\">Edit</a>",
            "<a href=\"#\" phx-click=\"delete_user\" phx-value=\"1\">Delete</a>",
          ],
        ],
        @static => [
          "    <tr>\n      <td>",
          "</td>\n      <td>",
          "</td>\n      <td>",
          "</td>\n\n      <td>\n",
          "        ",
          "\n",
          "      </td>\n    </tr>\n",
        ],
        :r => 1
      }
    }

  @deep_diff2 %{
      0 => %{
        0 => %{
          @dynamics => [["user1058", "2"]],
        },
      }
    }

  @deep_diff_result %{
      0 => %{
        0 => %{
          :new_render => true,
          @dynamics => [["user1058", "2"]],
          @static => ["        <tr>\n          <td>", " (", ")</td>\n        </tr>\n"],
          :r => 1
        },
        @static => [
          "  <table>\n    <thead>\n      <tr>\n        <th>Username</th>\n        <th></th>\n      </tr>\n    </thead>\n    <tbody>\n",
          "    </tbody>\n  </table>\n",
        ],
        :new_render => true,
        :r => 1,
      },
      1 => %{
        @dynamics => [
          [
            "asdf_asdf",
            "asdf@asdf.com",
            "123-456-7890",
            "<a href=\"/users/1\">Show</a>",
            "<a href=\"/users/1/edit\">Edit</a>",
            "<a href=\"#\" phx-click=\"delete_user\" phx-value=\"1\">Delete</a>",
          ],
        ],
        @static => [
          "    <tr>\n      <td>",
          "</td>\n      <td>",
          "</td>\n      <td>",
          "</td>\n\n      <td>\n",
          "        ",
          "\n",
          "      </td>\n    </tr>\n",
        ],
        :r => 1
      }
    }

  @static_reuse_diff %{
      0 => %{
        @dynamics => [
          ["foo", %{@dynamics => [["0", 1], ["1", 2]], @static => 0}],
          ["bar", %{@dynamics => [["0", 3], ["1", 4]], @static => 0}]
        ],
        @static => ["\n  <p>\n    ", "\n    ", "\n  </p>\n"],
        :r => 1,
        @templates => %{0 => ["<span>", ": ", "</span>"]}
      },
      @components => %{
        1 => %{0 => "index_1", 1 => "world", @static => ["<b>FROM ", " ", "</b>"], :r => 1},
        2 => %{0 => "index_2", 1 => "world", @static => 1, :r => 1},
        3 => %{0 => "index_1", 1 => "world", @static => 1, :r => 1},
        4 => %{0 => "index_2", 1 => "world", @static => 3, :r => 1}
      },
      @static => ["<div>", "</div>"],
      :r => 1
    }
  
  describe "merge_diff/2" do
    test "recursively merges two diffs" do
      simple = %Rendered{view_id: "123"}
      {_simple_diff1, simple} = Rendered.merge_diff(simple, @simple_diff1)
      {_simple_diff1, simple} = Rendered.merge_diff(simple, @simple_diff2)
      assert simple.rendered == Map.merge(@simple_diff_result, %{@components => %{}, :new_render => true})

      deep = %Rendered{view_id: "123"}
      {_deep_diff1, deep} = Rendered.merge_diff(deep, @deep_diff1)
      {_deep_diff2, deep} = Rendered.merge_diff(deep, @deep_diff2)
      assert deep.rendered == Map.merge(@deep_diff_result, %{@components => %{}})
    end

    test "merges the latter diff if it contains a `static` key" do
      diff1 = %{0 => ["a"], 1 => ["b"]}
      diff2 = %{0 => ["c"], @static => ["c"]}
      rendered = %Rendered{view_id: "123"}
      {_diff1, rendered} = Rendered.merge_diff(rendered, diff1)
      {diff2, rendered} = Rendered.merge_diff(rendered, diff2)
      assert rendered.rendered == Map.merge(diff2, %{@components => %{}})
    end

    test "merges the latter diff if it contains a `static` key even when nested" do
      diff1 = %{0 => %{0 => ["a"], 1 => ["b"]}}
      diff2 = %{0 => %{0 => ["c"], @static => ["c"]}}
      rendered = %Rendered{view_id: "123"}
      {_diff1, rendered} = Rendered.merge_diff(rendered, diff1)
      {diff2, rendered} = Rendered.merge_diff(rendered, diff2)
      assert rendered.rendered == Map.merge(diff2, %{@components => %{}})
    end

    test "merges components considering links" do
      diff1 = %{}
      diff2 = %{@components => %{1 => %{@static => ["c"]}, 2 => %{@static => 1}}}
      rendered = %Rendered{view_id: "123"}
      {_diff1, rendered} = Rendered.merge_diff(rendered, diff1)
      {_diff2, rendered} = Rendered.merge_diff(rendered, diff2)
      assert rendered.rendered == %{@components => %{1 => %{@static => ["c"]}, 2 => %{@static => ["c"]}}}
    end

    test "merges components considering old and new links" do
      diff1 = %{@components => %{1 => %{@static => ["old"]}}}
      diff2 = %{@components => %{
        1 => %{@static => ["new"]}, 
        2 => %{:new_render => true, @static => -1}, 
        3 => %{:new_render => true, @static => 1}
      }}
      rendered = %Rendered{view_id: "123"}
      {_diff1, rendered} = Rendered.merge_diff(rendered, diff1)
      {_diff2, rendered} = Rendered.merge_diff(rendered, diff2)
      assert rendered.rendered == %{
        @components => %{
          1 => %{@static => ["new"]},
          2 => %{@static => ["old"]},
          3 => %{@static => ["new"]}
        }
      }
    end

    test "merges components whole tree considering old and new links" do
      diff1 = %{@components => %{1 => %{0 => %{@static => ["nested"]}, @static => ["old"]}}}

      diff2 = %{
        @components => %{
          1 => %{0 => %{@static => ["nested"]}, @static => ["new"]},
          2 => %{0 => %{@static => ["replaced"]}, @static => -1},
          3 => %{0 => %{@static => ["replaced"]}, @static => 1},
          4 => %{@static => -1},
          5 => %{@static => 1}
        }
      }

      rendered1 = %Rendered{view_id: "123"}
      {_diff1, rendered1} = Rendered.merge_diff(rendered1, diff1)
      {_diff2, rendered1} = Rendered.merge_diff(rendered1, diff2)
      assert rendered1.rendered == %{
        @components => %{
          1 => %{0 => %{@static => ["nested"]}, @static => ["new"]},
          2 => %{0 => %{@static => ["replaced"]}, @static => ["old"]},
          3 => %{0 => %{@static => ["replaced"]}, @static => ["new"]},
          4 => %{0 => %{@static => ["nested"]}, @static => ["old"]},
          5 => %{0 => %{@static => ["nested"]}, @static => ["new"]},
        }
      }

      diff3 = %{
        @components => %{
          1 => %{0 => %{@static => ["newRender"]}, @static => ["new"]},
          2 => %{0 => %{@static => ["replaced"]}, @static => -1},
          3 => %{0 => %{@static => ["replaced"]}, @static => 1},
          4 => %{@static => -1},
          5 => %{@static => 1}
        }
      }

      rendered2 = %Rendered{view_id: "123", rendered: diff1}
      {_diff1, rendered2} = Rendered.merge_diff(rendered1, diff1)
      {_diff3, rendered2} = Rendered.merge_diff(rendered2, diff3)
      assert rendered2.rendered == %{
        @components => %{
          1 => %{0 => %{@static => ["newRender"]}, @static => ["new"]},
          2 => %{0 => %{@static => ["replaced"]}, @static => ["old"]},
          3 => %{0 => %{@static => ["replaced"]}, @static => ["new"]},
          4 => %{0 => %{@static => ["nested"]}, @static => ["old"]},
          5 => %{0 => %{@static => ["newRender"]}, @static => ["new"]},
        }
      }
    end

    test "replaces a string when a map is returned" do
      diff1 = %{0 => %{0 => "<button>Press Me</button>", @static => ""}}
      diff2 = %{0 => %{0 => %{0 => "val", @static => ""}, @static => ""}}
      rendered = %Rendered{view_id: "123"}
      {_diff1, rendered} = Rendered.merge_diff(rendered, diff1)
      {diff2, rendered} = Rendered.merge_diff(rendered, diff2)
      assert rendered.rendered == Map.merge(diff2, %{@components => %{}})
    end

    test "replaces a map when a string is returned" do
      diff1 = %{0 => %{0 => %{0 => "val", @static => ""}, @static => ""}}
      diff2 = %{0 => %{0 => "<button>Press Me</button>", @static => ""}}
      rendered = %Rendered{view_id: "123"}
      {_diff1, rendered} = Rendered.merge_diff(rendered, diff1)
      {diff2, rendered} = Rendered.merge_diff(rendered, diff2)
      assert rendered.rendered == Map.merge(diff2, %{@components => %{}})
    end

    test "expands shared static from cids" do
      mount_diff = %{
        0 => "",
        1 => "",
        2 => %{
          0 => "new post",
          1 => "",
          2 => %{
            :d => [[1], [2]],
            :s => ["", ""]
          },
          :s => ["h1", "h2", "h3", "h4"]
        },
        :c => %{
          1 => %{
            0 => "1008",
            1 => "chris_mccord",
            2 => "My post",
            3 => "1",
            4 => "0",
            5 => "1",
            6 => "0",
            7 => "edit",
            8 => "delete",
            :s => ["s0", "s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9"]
          },
          2 => %{
            0 => "1007",
            1 => "chris_mccord",
            2 => "My post",
            3 => "2",
            4 => "0",
            5 => "2",
            6 => "0",
            7 => "edit",
            8 => "delete",
            :s => 1
          }
        },
        :s => ["f1", "f2", "f3", "f4"],
        :title => "Listing Posts"
      }

      update_diff = %{
        2 => %{
          2 => %{
            :d => [[3]]
          }
        },
        :c => %{
          3 => %{
            0 => "1009",
            1 => "chris_mccord",
            2 => "newnewnewnewnewnewnewnew",
            3 => "3",
            4 => "0",
            5 => "3",
            6 => "0",
            7 => "edit",
            8 => "delete",
            :s => -2
          }
        }
      }

      rendered = %Rendered{view_id: "123", rendered: mount_diff}
      {_mount_diff, rendered} = Rendered.merge_diff(rendered, mount_diff)
      assert Rendered.get_component(rendered, 1) |> Map.get(@static) == Rendered.get_component(rendered, 2) |> Map.get(@static)
      {_update_diff, rendered} = Rendered.merge_diff(rendered, update_diff)
      shared_static = Rendered.get_component(rendered, 1)[@static]

      assert shared_static != nil
      assert shared_static == Rendered.get_component(rendered, 2)[@static]
      assert shared_static == Rendered.get_component(rendered, 3)[@static]
    end
  end

  describe "is_new_fingerprint?/1" do
    test "returns true if `diff.static` is truthy" do
      diff = %{@static => ["<h2>"]}
      rendered = %Rendered{view_id: "123"}
      assert Rendered.is_new_fingerprint?(diff) == true
    end

    test "returns false if `diff.static` is falsy" do
      diff = %{@static => nil}
      rendered = %Rendered{view_id: "123"}
      assert Rendered.is_new_fingerprint?(diff) == false
    end

    test "returns false if `diff` is undefined" do
      rendered = %Rendered{view_id: "123"}
      assert Rendered.is_new_fingerprint?() == false
    end
  end

  describe "to_string/1" do
    test "stringifies a diff" do
      rendered = %Rendered{view_id: "123"}
      {_simple_diff_result, rendered} = Rendered.merge_diff(rendered, @simple_diff_result)
      {:ok, str, _streams} = Rendered.to_string(rendered)
      expected = """
      <div data-phx-id="m1-123" class="thermostat">
        <div class="bar cooling">
          <a href="#" phx-click="toggle-mode">cooling</a>
          <span>07:15:04 PM</span>
        </div>
      </div>
      """ |> String.trim()
      
      assert String.trim(str) == expected
    end

    test "reuses static in components and comprehensions" do
      rendered = %Rendered{view_id: "123"}
      {_static_reuse_diff, rendered} = Rendered.merge_diff(rendered, @static_reuse_diff)
      {:ok, str, _streams} = Rendered.to_string(rendered)
      expected = """
      <div data-phx-id="m1-123">
        <p>
          foo
          <span>0: <b data-phx-id="c1-123" data-phx-component="1">FROM index_1 world</b></span><span>1: <b data-phx-id="c2-123" data-phx-component="2">FROM index_2 world</b></span>
        </p>

        <p>
          bar
          <span>0: <b data-phx-id="c3-123" data-phx-component="3">FROM index_1 world</b></span><span>1: <b data-phx-id="c4-123" data-phx-component="4">FROM index_2 world</b></span>
        </p>
      </div>
      """ |> String.trim()
      
      assert String.trim(str) == expected
    end
  end
end
