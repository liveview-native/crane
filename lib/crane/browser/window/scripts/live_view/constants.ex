defmodule LiveView.Constants do

  @consts %{
    binding_prefix: "phx-",
    consecutive_reloads: "consecutive-reloads",
    defaults: %{
      debounce: 300,
      throttle: 300
    },
    disconnected_timeout: 500,
    failsafe_jitter: 30_000,
    loader_timeout: 1,
    max_reloads: 10,
    phx_component: "data-phx-component",
    phx_lv_history_position: "phx:nav-history-position",
    phx_lv_profile: "phx:live-socket:profiling",
    phx_magic_id: "data-phx-id",
    phx_main: "data-phx-main",
    phx_parent_id: "data-phx-parent-id",
    phx_reload_status: "__phoenix_reload_status__",
    phx_ref_loading: "data-phx-ref-loading",
    phx_ref_lock: "data-phx-ref-lock",
    phx_ref_src: "data-phx-ref-src",
    phx_session: "data-phx-session",
    phx_skip: "data-phx-skip",
    phx_static: "data-phx-static",
    phx_sticky: "data-phx-sticky",
    reload_jitter_max: 10_000,
    reload_jitter_min: 5_000,
    transports: %{
      websocket: "websocket"
    },

    components: :c,
    dynamics: :d,
    static: :s,
    root: :r,
    events: :e,
    reply: :r,
    title: :t,
    templates: :p,
    stream: :stream
  }

  defmacro __using__(names) do
    @consts
    |> Map.take(names)
    |> Enum.each(fn({name, value}) -> 
      Module.put_attribute(__CALLER__.module, name, value)
    end)
  end
end
