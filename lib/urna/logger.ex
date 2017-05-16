defmodule Urna.Logger do
  defmacro __using__(_opts) do
    quote do
      require Logger
      require Urna.Logger
      alias Urna.Logger
    end
  end

  defmacro metadata(data \\ []) do
    quote do
      Keyword.merge(unquote(data), [
        uri:     var!(uri, Urna),
        params:  var!(params, Urna),
        headers: var!(req, Urna).headers ])
    end
  end

  defmacro request do
    quote do
      request = var!(req, Urna)
      uri     = var!(uri, Urna)
      params  = var!(params, Urna)
      headers = request.headers

      output = "#{request.method} #{uri}\n\n#{headers |> to_string |> String.trim}"

      output = if params do
        output <> "\n\n#{inspect(params, pretty: true, width: 0)}"
      else
        output
      end

      output
    end
  end

  defmacro debug(what, meta \\ []) do
    quote do
      Elixir.Logger.debug(
        Urna.Logger.request <> "\n\n" <> unquote(what),
        Urna.Logger.metadata(unquote(meta)))
    end
  end

  defmacro info(what, meta \\ []) do
    quote do
      Elixir.Logger.info(
        Urna.Logger.request <> "\n\n" <> unquote(what),
        Urna.Logger.metadata(unquote(meta)))
    end
  end

  defmacro warn(what, meta \\ []) do
    quote do
      Elixir.Logger.warn(
        Urna.Logger.request <> "\n\n" <> unquote(what),
        Urna.Logger.metadata(unquote(meta)))
    end
  end

  defmacro error(what, meta \\ []) do
    quote do
      Elixir.Logger.error(
        Urna.Logger.request <> "\n\n" <> unquote(what),
        Urna.Logger.metadata(unquote(meta)))
    end
  end
end
