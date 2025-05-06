defmodule Crane.Browser.Window.Location do
  defstruct href: nil,
    protocol: nil,
    host: nil,
    hostname: nil,
    port: nil,
    pathname: nil,
    search: nil,
    hash: nil,
    origin: nil

  def new(url) do
    uri = URI.parse(url)

    %__MODULE__{
      href: url,
      host: uri.authority,
      hostname: uri.host, 
      pathname: uri.path,
      protocol: protocol(uri),
      search: search(uri),
      hash: hash(uri),
      origin: origin(uri)
    }
  end

  defp protocol(%URI{scheme: scheme}),
    do: "#{scheme}:"

  defp search(%URI{query: nil}),
    do: ""
  defp search(%URI{query: query}),
    do: "?#{query}"

  defp hash(%URI{fragment: nil}),
    do: ""
  defp hash(%URI{fragment: fragment}),
    do: "##{fragment}"

  defp origin(%URI{scheme: scheme, authority: authority}),
    do: "#{scheme}://#{authority}"
end
