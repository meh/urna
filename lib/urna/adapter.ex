defmodule Urna.Adapter do
  defmacro __using__(_opts) do
    quote do
      @behaviour Urna.Adapter
    end
  end

  use Behaviour

  defcallback accept?(mime_type :: String.t) :: boolean

  defcallback encode(mime_type :: String.t, term)
    :: { mime_type :: String.t, encoded :: String.t }

  defcallback decode(mime_type :: String.t, String.t)
    :: { :ok, decoded :: term } | { :error, reason :: term }
end
