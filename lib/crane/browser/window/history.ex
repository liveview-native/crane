defmodule Crane.Browser.Window.History do
  @option_keys [:url, :method, :headers]

  alias Crane.Protos

  defstruct stack: [],
    index: -1

  def go(%__MODULE__{index: index, stack: stack} = history, offset \\ 0) do
    case Enum.at(stack, index + offset) do
      nil -> {:error, "no history frame in stack for index offset of #{offset} from #{index}"}
      frame -> {:ok, frame, %{history | index: index + offset}}
    end
  end

  def push_state(%__MODULE__{index: index, stack: stack} = history, state, options) when is_map(state) and is_list(options) do
    case Keyword.has_key?(options, :url) do
      false -> {:error, ":url option must be passed in"}
      true ->
        index = index + 1

        {kept_stack, _tossed_stack} = Enum.split(stack, index)
        options = Keyword.take(options, @option_keys)
        frame = {state, options}

        {
          :ok,
          frame,
          %{history | stack: List.insert_at(kept_stack, index, frame), index: index}
        }
    end
  end

  def replace_state(%__MODULE__{index: index, stack: stack} = history, state, options) when is_map(state) do
    case Keyword.has_key?(options, :url) do
      false -> {:error, ":url option must be passed in"}
      true ->
        options = Keyword.take(options, @option_keys)
        frame = {state, options}

        {
          :ok,
          frame,
          %{history | stack: List.replace_at(stack, index, frame)}
        }
    end
  end

  def to_protoc(%__MODULE__{index: index, stack: stack}) do
    %Protos.Browser.Window.History{
      index: index,
      stack: Enum.map(stack, fn(frame) ->
        %Protos.Browser.Window.History.Frame{
          state: elem(frame, 0),
          url: elem(frame, 1)[:url]
        }
      end)
    }
  end
end
