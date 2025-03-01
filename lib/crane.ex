defmodule Crane do
  def fetch(window, url, options \\ []) do
    GenServer.call(window.pid, {:fetch, url, options})
  end

  def forward(window) do
    GenServer.call(window.pid, :forward)
  end

  def back(window) do
    GenServer.call(window.pid, :back) 
  end
end
