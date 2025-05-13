defmodule LiveView.Browser do
  alias Crane.Browser.{
    Window,
    Window.History
  }

  def push_state(%Window{history: history} = window, kind, meta, to \\ nil) do
    if to !== window.location.href do
      history = if meta.type == :redirect && meta[:scroll] do
        {state, opts} = History.current_frame(history)
        state = Map.put(state, :scroll, meta[:scroll])
        {:ok, _frame, history} = History.replace_state(history, state, opts)
      else
        history
      end
  
      meta = Map.delete(meta, :scroll)  
      history = apply(History, String.to_atom("#{kind}_state"), [history, meta, [url: window.location.href]])

      {:ok, window} = Window.update(window, history: history)
      window
    else
      window
    end
  end

  def update_current_state(%Window{history: history} = window, callback) do
    {state, options} = History.current_frame(history)
    history = History.replace_state(history, callback.(history.state), options)
    {:ok, window} = Window.update(window, history: history)
    window
  end

  def drop_local(_storage, _pathname, _reloads),
    do: :ok
end
