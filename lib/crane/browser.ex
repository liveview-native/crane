defmodule Crane.Browser do
  import Crane.Utils

  alias HttpCookie.Jar
  alias Crane.Browser.Window

  @default_headers [
    {"Accept-Encoding", "gzip, deflate, br, zstd"},
    {"Accept-Language", "en-US,en;q=0.5"},
    {"User-Agent", "Crane/1.0"},
    {"Upgrade-Insecure-Requests", "1"},
  ]

  use Crane.Object,
    headers: [],
    cookie_jar: Jar.new()

  defchild window: Window

  @impl true
  def handle_continue({:init, _opts}, browser) do
    {:noreply, %__MODULE__{browser | headers: @default_headers ++ browser.headers}}
  end

  def handle_continue(_continue_arg, browser),
    do: {:noreply, browser}

  def handle_call({:restore_window, %Window{} = window_state}, _from, %__MODULE__{refs: refs} = browser) do
    with {:ok, window} <- Window.restore(window_state),
      refs <- monitor(window, refs) do
        browser = %__MODULE__{browser | refs: refs}
        broadcast(Crane, {:restore_window, window, browser})
        {:reply, {:ok, window, browser}, browser}
    else
      error -> {:reply, error, browser}
    end
  end

  def handle_call(_msg, _from, browser) do
    {:reply, browser}
  end

  @impl true
  def handle_cast({:update_cookie_jar, cookie_jar}, browser) do
    broadcast(Crane, {:update, browser})
    {:noreply, %__MODULE__{browser | cookie_jar: cookie_jar}}
  end

  def handle_cast(_msg, browser) do
    {:noreply, browser}
  end

  def handle_info(_msg, browser) do
    {:noreply, browser}
  end

  def update_cookie_jar(%__MODULE__{name: name}, cookie_jar) do
    GenServer.cast(name, {:update_cookie_jar, cookie_jar})
  end

  def restore_window(%__MODULE__{name: name}, %Window{} = window_state \\ %Window{}) do
    GenServer.call(name, {:restore_window, %Window{window_state | browser_name: name}})
  end

  def strip!(%__MODULE__{} = browser),
    do: %__MODULE__{
      name: browser.name
    }
end
