defmodule Crane.Phoenix.Live.Console do
  use Phoenix.LiveView,
    layout: {Crane.Phoenix.Layout, :console}

  alias Crane.Phoenix.Live.Console.{
    BrowserState,
    WindowState
  }

  alias Crane.{
    Browser,
    Browser.Window
  }

  import Crane.Utils

  def mount(_parms, _session, socket) do
    {:ok, browsers} = Crane.browsers()

    subscribe(Crane)
    Enum.each(browsers, &(subscribe(&1.name)))

    socket =
      socket
      |> assign( 
        refs: %{},
        browsers: browsers,
        dark_theme: true,
        active_browser: Enum.at(browsers, 0),
        browser_states: BrowserState.build(browsers))
      |> render_with(&Crane.Phoenix.Live.Console.HTML.render/1)
    {:ok, socket}
  end

  def handle_event("new_browser", _params, socket) do
    {:ok, browser, _crane} = Crane.new_browser()

    {:noreply, assign(socket,
      browsers: Crane.browsers!(),
      active_browser: browser)
    }
  end

  def handle_event("new_window", _params, socket) do
    {:ok, window, browser} = Crane.Browser.new_window(socket.assigns.active_browser)

    {:noreply, update_active_browser_state(socket, active_window: window)}
  end

  def handle_event("active_browser", %{"browser" => browser_name}, socket) do
    {:ok, browser} = Crane.Browser.get(browser_name)

    {:noreply, assign(socket, active_browser: browser)}
  end

  def handle_event("active_window", %{"window" => window_name}, socket) do
    {:ok, window} = Crane.Browser.Window.get(window_name)

    {:noreply, update_active_browser_state(socket, active_window: window)}
  end

  def handle_event("close_browser", %{"browser" => browser_name}, socket) do
    {:ok, browser} = Crane.Browser.get(browser_name)
    {:ok, _crane} = Crane.close_browser(browser)

    {:noreply, socket}
  end

  def handle_event("close_window", %{"window" => window_name}, socket) do
    {:ok, browser} = Crane.Browser.get(socket.assigns.active_browser)
    {:ok, window} = Crane.Browser.Window.get(window_name)
    {:ok, _browser} = Crane.Browser.close_window(browser, window)

    {:noreply, socket}
  end

  def handle_event("set_active_tab", %{"tab" => tab}, socket) do
    {:noreply, update_active_window_state(socket, active_tab: tab)}
  end

  def handle_event("toggle_theme", _parmas, socket) do
    {:noreply, update(socket, :dark_theme, &(!&1))}
  end

  def handle_info({:DOWN, ref, _, _, _}, socket) do
    name = Map.get(socket.assigns.refs, ref)

    refs = demonitor(ref, socket.assigns.refs)

    socket =
      socket
      |> down(name)
      |> assign(refs: refs)

    {:noreply, socket}
  end

  def handle_info({:new_browser, browser}, socket) do
    subscribe(browser.name)
    refs = monitor(browser, socket.assigns.refs)

    browser_states = Map.put(socket.assigns.browser_states, browser.name, %BrowserState{})

    {:noreply, assign(socket,
      refs: refs,
      browser_states: browser_states)
    }
  end

  def handle_info({:new_window, window, browser}, socket) do
    subscribe(window.name)
    refs = monitor(window, socket.assigns.refs)

    window_states =
      socket.assigns.browser_states
      |> get_in([window.browser_name, :window_states])
      |> Map.put(window.name, %WindowState{})

    browsers = Crane.browsers!()

    socket =
      socket
      |> update_active_browser_state(window_states: window_states)
      |> assign(
        active_browser: update_if_active(browser.name, socket.assigns.active_browser),
        browsers: browsers,
        refs: refs)

    {:noreply, socket}
  end

  defp down(socket, name) when is_atom(name) do
    down(socket, Atom.to_string(name))
  end

  defp down(socket, "browser-" <> _id = name) do
    browser_name = String.to_existing_atom(name)
    active_browser = new_active(socket.assigns.browsers, browser_name, socket.assigns.active_browser)
    browsers = Enum.reject(socket.assigns.browsers, &(browser_name == &1.name))

    unsubscribe(browser_name)

    socket
    |> delete_browser_state(browser_name)
    |> assign(active_browser: active_browser, browsers: browsers)
  end

  defp down(socket, "window-" <> _id = name) do
    window_name = String.to_existing_atom(name)
    IO.inspect({window_name, socket.assigns.browser_states})
    {browser_name, _browser_state} = Enum.find(socket.assigns.browser_states, fn({_name, browser_state}) ->
      window_name in Map.keys(browser_state.window_states)
    end)

    {:ok, %Browser{name: browser_name} = browser} = Browser.get(browser_name)
    {:ok, windows} = Browser.windows(browser)

    active_window = get_in(socket.assigns, [:browser_states, browser.name, :active_window])

    unsubscribe(window_name)

    browsers = Enum.map(socket.assigns.browsers, fn
      %Crane.Browser{name: ^browser_name} -> browser
      other -> other
    end)

    socket
    |> delete_window_state(window_name)
    |> update_active_browser_state(active_window: new_active(windows, window_name, active_window))
    |> assign(active_browser: browser, browsers: browsers)
  end

  defp delete_browser_state(socket, browser_name) do
    {_window_state, browser_states} = pop_in(socket.assigns.browser_states, [browser_name])

    assign(socket, browser_states: browser_states)
  end

  defp delete_window_state(socket, window_name) do
    browser = socket.assigns.active_browser
    {_window_state, browser_states} = pop_in(socket.assigns.browser_states, [browser.name, :window_states, window_name])

    assign(socket, browser_states: browser_states)
  end

  defp update_active_browser_state(socket, state_update) do
    state_update = Map.new(state_update)
    browser = socket.assigns.active_browser
    browser_state = Map.merge(socket.assigns.browser_states[browser.name], state_update)
    browser_states = Map.put(socket.assigns.browser_states, browser.name, browser_state)

    assign(socket, browser_states: browser_states)
  end

  defp update_active_window_state(socket, state_update) do
    state_update = Map.new(state_update)
    browser = socket.assigns.active_browser
    browser_state = socket.assigns.browser_states[browser.name]
    window = browser_state.active_window
    window_state = Map.merge(browser_state.window_states[window.name], state_update)
    window_states = Map.put(browser_state.window_states, window.name, window_state)
    browser_state = Map.put(browser_state, :window_states, window_states)
    browser_states = Map.put(socket.assigns.browser_states, browser.name, browser_state)

    assign(socket, browser_states: browser_states)
  end

  defp update_if_active(name, %{name: name} = resource),
    do: resource
  defp update_if_active(_name, _active),
    do: nil

  defp new_active([], _name, _active),
    do: nil
  defp new_active(_list, _name, nil),
    do: nil

  defp new_active(list, name, %{name: name} = resource) do
    idx = Enum.find_index(list, &(name == &1.name))
    length = length(list)

    if idx == length - 1 do
      idx = idx - 1
      if idx < 0 do
        nil
      else
        Enum.at(list, idx, nil)
      end
    else
      Enum.at(list, idx + 1, nil)
    end
  end

  defp new_active(_list, _name, active),
    do: active
end

