defmodule Crane.URI do
  def normalize(uri) do
    case URI.parse(uri) do
      %URI{scheme: nil} = uri -> %URI{uri | scheme: "https"}
      uri -> uri
    end
    |> URI.to_string()
  end
end
