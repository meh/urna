#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Urna do
  alias Data.Stack

  def start(what, listener) do
    Cauldron.start what, listener
  end

  def start_link(what, listener) do
    Cauldron.start_link what, listener
  end

  defmacro __using__(_opts) do
    quote do
      import Urna

      @before_compile unquote(__MODULE__)
      @resource false
      @endpoint Data.Stack.Simple.new
    end
  end

  @verbs head:   "HEAD",
         get:    "GET",
         post:   "POST",
         put:    "PUT",
         delete: "DELETE"

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      def handle(method, _, req) when not method in unquote(Keyword.values(@verbs)) do
        req.reply(405)
      end

      def handle(_, uri, req) do
        req.reply(404)
      end
    end
  end

  defmacro namespace(name, do: body) do
    quote do
      if @resource do
        raise ArgumentError, message: "cannot nest a namespace in a resource"
      end

      @endpoint Stack.push(@endpoint, to_string(unquote(name)))

      unquote(body)

      @endpoint Stack.pop(@endpoint) |> elem(1)
    end
  end

  defmacro resource(name, do: body) do
    quote do
      @resource true
      @endpoint Stack.push(@endpoint, to_string(unquote(name)))

      unquote(body)

      @path endpoint_to_path(@endpoint)

      def handle(_, URI.Info[path: @path], req) do
        req.reply(405)
      end

      def handle(_, URI.Info[path: @path <> "/" <> _], req) do
        req.reply(405)
      end

      @endpoint Stack.pop(@endpoint) |> elem(1)
      @resource false
    end
  end

  defmacro verb(name, do: body) do
    quote bind_quoted: [method: to_string(name) |> String.upcase, body: Macro.escape(body)] do
      @path endpoint_to_path(@endpoint)

      if @resource do
        def handle(unquote(method), URI.Info[path: @path] = uri, req) do
          body_to_response unquote(body)
        end
      else
        raise ArgumentError, message: "cannot define standalone verb outside a resource"
      end
    end
  end

  defmacro verb(name, variable, do: body) do
    quote bind_quoted: [method: to_string(name) |> String.upcase, variable: Macro.escape(variable), body: Macro.escape(body)] do
      @path endpoint_to_path(@endpoint)

      if @resource do
        def handle(unquote(method), URI.Info[path: @path <> "/" <> unquote(variable)] = uri, req) do
          body_to_response unquote(body)
        end
      else
        def handle(unquote(method), URI.Info[path: @path <> "/" <> unquote(to_string(variable))] = uri, req) do
          body_to_response unquote(body)
        end
      end
    end
  end

  Enum.each @verbs, fn { name, method } ->
    defmacro unquote(name)(do: body) do
      method = unquote(method)

      quote do
        verb(unquote(method), do: unquote(body))
      end
    end

    defmacro unquote(name)(variable, do: body) do
      method = unquote(method)

      quote do
        verb(unquote(method), unquote(variable), do: unquote(body))
      end
    end
  end

  @doc false
  def endpoint_to_path(stack) do
    "/" <> (Data.to_list(stack) |> Data.reverse |> Enum.join("/"))
  end

  @doc false
  defmacro body_to_response(body) do
    quote do
      content = req.body
      decoded = if content do
        case req.headers["Content-Type"] || "application/json" do
          "application/json" ->
            JSON.decode!(content)

          "application/x-www-form-urlencoded" ->
            { :ok, URI.decode_query(content, []) }

          _ ->
            { :error, :unsupported_content_type }
        end
      else
        { :ok, nil }
      end

      case decoded do
        { :ok, __params__ } ->
          __uri__ = uri

          case unquote(body) do
            { code } when is_integer(code) ->
              req.reply(code)

            { code, text } when is_integer(code) and is_binary(text) ->
              req.reply({ code, text })

            { code, headers } when is_integer(code) ->
              req.reply.status(code).headers(headers).body("")

            { code, text, headers } when is_integer(code) and is_binary(text) ->
              req.reply.status({ code, text }).headers(headers).body("")

            result ->
              req.reply(200, [{ "Content-Type", "application/json" }], JSON.encode!(result))
          end

        { :error, _ } ->
          req.reply(406)
      end
    end
  end

  defmacro headers do
    quote do: req.headers
  end

  defmacro params do
    quote do: __params__
  end

  defmacro uri do
    quote do: __uri__
  end

  defmacro query do
    quote do: URI.decode_query(__uri__.query, [])
  end

  defmacro success(code) when code in 100 .. 399 do
    quote do
      { unquote(code) }
    end
  end

  defmacro success(code, text_or_headers) when code in 100 .. 399 do
    quote do
      { unquote(code), unquote(text_or_headers) }
    end
  end

  defmacro success(code, text, headers) when code in 100 .. 399 do
    quote do
      { unquote(code), unquote(text), unquote(headers) }
    end
  end

  defmacro fail(code) when code in 400 .. 599 do
    quote do
      { unquote(code) }
    end
  end

  defmacro fail(code, text_or_headers) when code in 400 .. 599 do
    quote do
      { unquote(code), unquote(text_or_headers) }
    end
  end

  defmacro fail(code, text, headers) when code in 400 .. 599 do
    quote do
      { unquote(code), unquote(text), unquote(headers) }
    end
  end

  defmacro redirect(uri) do
    quote do
      { 301, [{ "Location", to_string(unquote(uri)) }] }
    end
  end
end
