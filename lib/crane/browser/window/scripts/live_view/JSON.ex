defmodule LiveView.JSON do
  use LiveView.Constants, [
    :components,
    :dynamics,
    :static,
    :root,
    :events,
    :reply,
    :title,
    :templates,
    :stream
  ]

  defdelegate encode!(json), to: Elixir.JSON

  def decode!(json) do
    {decoded, _acc, _rest} =
      Elixir.JSON.decode(json, %{}, [
        object_push: fn(key, value, acc) ->
          case {key, value, acc} do
            {key, value, acc} -> [{convert_key(key), value} | acc]
          end
        end
      ])

    decoded
  end

  @to_atom_keys Enum.map([
    @components,
    @dynamics,
    @static,
    @root,
    @events,
    @reply,
    @title,
    @templates,
    @stream
  ], &Atom.to_string(&1))

  @numbers ?0..?9 

  def convert_key(key) when key in @to_atom_keys,
    do: String.to_existing_atom(key)
  def convert_key(<<digit, rest::binary>> = key) when digit in @numbers,
    do: parse_integer(rest, to_int(digit), key)
  def convert_key(key),
    do: key

  defp parse_integer(<<>>, number, _original),
    do: number
  defp parse_integer(<<digit, rest::binary>>, number, original) when digit in @numbers,
    do: parse_integer(rest, number * 10 + to_int(digit), original)
  defp parse_integer(_other, _number, original),
    do: original

  defp to_int(number),
    do: number - 48
end
