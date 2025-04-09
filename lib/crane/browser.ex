defmodule Crane.Browser do
  use GenServer
  import Crane.Utils

  alias HttpCookie.Jar
  alias Crane.Browser.Window
  alias Crane.Protos

  @default_headers [
    {"Accept-Encoding", "gzip, deflate, br, zstd"},
    {"Accept-Language", "en-US,en;q=0.5"},
    {"User-Agent", "Crane/1.0"},
    {"Upgrade-Insecure-Requests", "1"},
  ]

  defstruct name: nil,
    refs: %{},
    created_at: nil,
    headers: [],
    cookie_jar: Jar.new()

  def start_link(args) do
    name = generate_name(:browser)

    args = Keyword.put(args, :name, name)

    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(args) do
    headers = Keyword.get(args, :headers, [])
    Process.flag(:trap_exit, true)

    {:ok, %__MODULE__{
      headers: @default_headers ++ headers,
      created_at: DateTime.now!("Etc/UTC"),
      name: args[:name] 
    }}
  end

  def handle_call(:get, _from, browser),
    do: {:reply, {:ok, browser}, browser}

  def handle_call({:get, %__MODULE__{headers: headers}}, _from, browser) do
    browser = %__MODULE__{browser | headers: browser.headers ++ headers}
    {:reply, {:ok, browser}, browser}
  end

  def handle_call(:windows, _from, %__MODULE__{refs: refs} = browser) do
    windows = get_reference_resource(refs, :window, fn(name) ->
      Window.get(name)
    end)
    |> Enum.sort_by(&(&1.created_at), {:asc, DateTime})

    {:reply, {:ok, windows}, browser}
  end

  def handle_call({:restore_window, %Window{} = window_state}, _from, %__MODULE__{name: name, refs: refs} = browser) do
    with {:ok, window} <- Window.restore(window_state),
      refs <- monitor(window, refs) do

      browser = %__MODULE__{browser | refs: refs}

      broadcast(name, {:restore_window, window})

      {:reply, {:ok, window, browser}, browser}
    else
      error -> {:reply, error, browser}
    end
  end

  def handle_call(:new_window, _from, %__MODULE__{name: name, refs: refs} = browser) do
    with {:ok, window} <- Window.new([browser: browser]),
      refs <- monitor(window, refs) do

      browser = %__MODULE__{browser | refs: refs}

      broadcast(name, {:new_window, window, browser})

      {:reply, {:ok, window, browser}, browser}
    else
      error -> {:reply, error, browser}
    end
  end

  def handle_call(_msg, _from, browser) do
    {:noreply, browser}
  end

  def handle_cast({:update_cookie_jar, cookie_jar}, %__MODULE__{name: name} = browser) do
    broadcast(name, {:update_cookie_jar, browser})
    {:noreply, %__MODULE__{browser | cookie_jar: cookie_jar}}
  end

  def handle_cast(_msg, browser) do
    {:noreply, browser}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, %__MODULE__{refs: refs} = browser) do
    {_name, refs} = Map.pop(refs, ref)

    {:noreply, %__MODULE__{browser | refs: refs}}
  end

  def handle_info(_msg, browser) do
    {:noreply, browser}
  end

  def update_cookie_jar(%__MODULE__{name: name}, cookie_jar) do
    GenServer.cast(name, {:update_cookie_jar, cookie_jar})
  end

  def windows(%__MODULE__{name: name}) do
    GenServer.call(name, :windows)
  end

  def windows!(browser) do
    {:ok, windows} = windows(browser)
    windows
  end

  def restore_window(%__MODULE__{name: name}, %Window{} = window_state \\ %Window{}) do
    GenServer.call(name, {:restore_window, %Window{window_state | browser_name: name}})
  end

  def new_window(%__MODULE__{name: name}) do
    GenServer.call(name, :new_window)
  end

  def close_window(%__MODULE__{name: name} = browser, %Window{} = window) do
    :ok = Window.close(window)
    get(browser)
  end

  def new(state \\ []) when is_list(state) do
    with {:ok, pid} <- start_link(state),
      {:ok, browser} <- GenServer.call(pid, :get) do
        {:ok, browser}
    else
      error -> {:error, error}
    end
  end

  def close(%__MODULE__{name: name}) do
    GenServer.stop(name, :normal)
  end

  def get(%__MODULE__{name: name}),
    do: get(name)

  def get(name) when is_binary(name),
    do: get(String.to_existing_atom(name))

  def get(name) when is_atom(name) do
    GenServer.call(name, :get)
  end

  def get!(resource_or_name) do
    {:ok, window} = get(resource_or_name)
    window
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
