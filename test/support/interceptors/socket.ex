defmodule Crane.TestInterceptors.Socket do

  def init(_args) do
    []
  end

  def call(request, stream, next, _options) do
    next.(request, stream)
  end
end
