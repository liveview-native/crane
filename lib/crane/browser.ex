defmodule Crane.Browser do
  use GenServer
  alias HttpCookie.Jar
  alias Crane.Protos

  import Crane.Utils

  @default_headers [
    {"Accept-Encoding", "gzip, deflate, br, zstd"},
    {"Accept-Language", "en-US,en;q=0.5"},
    {"User-Agent", "Crane/1.0"},
    {"Upgrade-Insecure-Requests", "1"},
  ]

  alias Crane.Browser.Window

  defstruct name: nil,
    refs: %{},
    headers: [],
    cookie_jar: Jar.new()

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    headers = Keyword.get(args, :headers, [])
    Process.flag(:trap_exit, true)

    {:ok, %__MODULE__{
      headers: @default_headers ++ headers,
      name: generate_name(:browser)
    }}
  end

  def handle_call({:get, %__MODULE__{headers: headers}}, _from, browser) do
    browser = %__MODULE__{browser | headers: browser.headers ++ headers}
    {:reply, {:ok, browser}, browser}
  end

  def handle_call(:windows, _from, %__MODULE__{refs: refs} = browser) do
    windows = Enum.reduce(refs, [], fn
      {_ref, "window-" <> _id = name}, acc ->
        {:ok, window} = Crane.Browser.Window.get(name)
        [window | acc]
      _other, acc -> acc
    end)

    {:reply, {:ok, windows}, browser}
  end

  def handle_call({:new_window, window_state}, _from, %{refs: refs} = browser) do
    with {:ok, window} <- Window.new(window_state),
      refs <- monitor(window, refs) do

      browser = %__MODULE__{browser | refs: refs}

      {:reply, {:ok, window, browser}, browser}
    else
      error -> {:reply, error, browser}
    end
  end

  def handle_call(_msg, _from, browser) do
    {:noreply, browser}
  end

  def handle_cast({:update_cookie_jar, cookie_jar}, browser) do
    {:noreply, %__MODULE__{browser | cookie_jar: cookie_jar}}
  end

  def handle_cast(_msg, browser) do
    {:noreply, browser}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{refs: refs} = browser) do
    {_name, refs} = Map.pop(refs, ref)

    {:noreply, %__MODULE__{browser | refs: refs}}
  end

  def handle_info(_msg, browser) do
    {:noreply, browser}
  end

  def update_cookie_jar(cookie_jar) do
    GenServer.cast(__MODULE__, {:update_cookie_jar, cookie_jar})
  end

  def windows(%__MODULE__{name: _name}) do
    GenServer.call(__MODULE__, :windows)
  end

  def new_window(%__MODULE__{name: _name}, window_state \\ %{}) when is_map(window_state) do
    GenServer.call(__MODULE__, {:new_window, Map.put(window_state, :browser_name, __MODULE__)})
  end

  def get(%__MODULE__{} = browser \\ %__MODULE__{}) do
    GenServer.call(__MODULE__, {:get, browser})
  end

  def to_proto(%__MODULE__{name: name, headers: headers, refs: refs} = _browser) do
    headers = Enum.map(headers, &to_proto(&1))
    windows = get_reference_names(refs, :window)

    %Protos.Browser{name: Atom.to_string(name), headers: headers, windows: windows}
  end

  def to_proto({name, %Window{} = window}) do
    {name, Window.to_proto(window)}
  end

  def to_proto({name, value}) do
    %Protos.Browser.Header{name: name, value: value}
  end
end
