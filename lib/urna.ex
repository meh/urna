#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Urna do
  alias Data.Stack

  def open(what, options // []) do
    Cauldron.open(what, options)
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
  defmacro __before_compile__(env) do
    methods = Keyword.values(@verbs)

    quote do
      def handle(method, _, req) when not method in unquote(methods) do
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

      @endpoint Stack.push(@endpoint, to_binary(unquote(name)))

      unquote(body)

      @endpoint Stack.pop(@endpoint) |> elem(1)
    end
  end

  defmacro resource(name, do: body) do
    quote do
      @resource true
      @endpoint Stack.push(@endpoint, to_binary(unquote(name)))

      unquote(body)

      path = endpoint_to_path(@endpoint)

      def :handle, [ quote(do: _),
                     quote(do: URI.Info[path: unquote(path)]),
                     quote(do: req) ], [], do: (quote do
        req.reply(405)
      end)

      def :handle, [ quote(do: _),
                     quote(do: URI.Info[path: unquote(path) <> "/" <> rest]),
                     quote(do: req) ], [], do: (quote do
        req.reply(405)
      end)

      @endpoint Stack.pop(@endpoint) |> elem(1)
      @resource false
    end
  end

  Enum.each @verbs, fn { name, method } ->
    defmacro unquote(name)(do: body) do
      method = unquote(method)
      body   = Macro.escape(body)

      quote do
        path = endpoint_to_path(@endpoint)
        body = unquote(body)

        def :handle, [ unquote(method),
                       quote(do: URI.Info[path: unquote(path)] = uri),
                       quote(do: req) ], [], do: (quote do
          body_to_response unquote(body)
        end)
      end
    end

    defmacro unquote(name)(name, do: body) do
      method = unquote(method)
      name   = Macro.escape(name)
      body   = Macro.escape(body)

      quote do
        path = endpoint_to_path(@endpoint)
        name = unquote(name)
        body = unquote(body)

        def :handle, [ unquote(method),
                       quote(do: URI.Info[path: unquote(path) <> "/" <> unquote(name)] = uri),
                       quote(do: req) ], [], do: (quote do
          body_to_response unquote(body)
        end)
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
            JSEX.decode(content)

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
            { code } ->
              req.reply(code)

            { code, text } when is_binary(text) ->
              req.reply({ code, text })

            { code, headers } ->
              req.reply.status(code).headers(headers).body("")

            { code, text, headers } ->
              req.reply.status({ code, text }).headers(headers).body("")

            result ->
              req.reply(200, [{ "Content-Type", "application/json" }], JSEX.encode!(result))
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
end
