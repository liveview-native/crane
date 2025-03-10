defmodule Crane.Browser do
  use GenServer
  alias HttpCookie.Jar
  alias Crane.Protos

  @default_headers [
    {"Accept-Encoding", "gzip, deflate, br, zstd"},
    {"Accept-Language", "en-US,en;q=0.5"},
    {"User-Agent", "Crane/1.0"},
    {"Upgrade-Insecure-Requests", "1"},
  ]

  alias Crane.Browser.Window

  defstruct windows: %{},
    name: nil,
    refs: %{},
    headers: [],
    cookie_jar: Jar.new()

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    headers = Keyword.get(args, :headers, [])

    {:ok, %__MODULE__{
      headers: @default_headers ++ headers
    }}
  end

  def handle_call({:get, %__MODULE__{headers: headers}}, _from, browser) do
    browser = %__MODULE__{browser | headers: browser.headers ++ headers}
    {:reply, {:ok, browser}, browser}
  end

  def handle_call({:new_window, window_state}, _from, %{windows: windows, refs: refs} = browser) do
    with {:ok, window} <- Window.new(window_state),
      {windows, refs} <- monitor_window(window, windows, refs) do

      {:reply, {:ok, window}, %__MODULE__{browser | windows: windows, refs: refs}}
    else
      error -> {:reply, error, browser}
    end
  end

  def handle_cast({:update_cookie_jar, cookie_jar}, browser) do
    {:noreply, %__MODULE__{browser | cookie_jar: cookie_jar}}
  end

  defp monitor_window(window, windows, refs) do
    pid = Process.whereis(window.name)
    ref = Process.monitor(pid)
    windows = Map.put(windows, window.name, window)
    refs = Map.put(refs, ref, window.name)

    {windows, refs}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{windows: windows, refs: refs} = browser) do
    {name, refs} = Map.pop(refs, ref)
    windows = Map.delete(windows, name)

    {:noreply, %__MODULE__{browser | windows: windows, refs: refs}}
  end

  def update_cookie_jar(cookie_jar) do
    GenServer.cast(__MODULE__, {:update_cookie_jar, cookie_jar})
  end

  def new_window(window_state \\ %{}) when is_map(window_state) do
    GenServer.call(__MODULE__, {:new_window, Map.put(window_state, :browser_name, __MODULE__)})
  end

  def get(%__MODULE__{} = browser \\ %__MODULE__{}) do
    GenServer.call(__MODULE__, {:get, browser})
  end

  def to_proto(%__MODULE__{name: name, headers: headers, windows: windows} = _browser) do
    headers = Enum.map(headers, &to_proto(&1))
    windows  = Enum.into(windows, %{}, &Window.to_proto(&1))

    %Protos.Browser{name: name, headers: headers, windows: windows}
  end

  def to_proto({name, %Window{} = window}) do
    {name, Window.to_proto(window)}
  end

  def to_proto({name, value}) do
    %Protos.Browser.Header{name: name, value: value}
  end
end
