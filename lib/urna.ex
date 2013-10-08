#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Urna do
  alias Data.Stack
  alias Data.Dict

  def start(what, listener) do
    Cauldron.start what, listener
  end

  def start_link(what, listener) do
    Cauldron.start_link what, listener
  end

  defmacro __using__(opts) do
    quote do
      import Urna

      @headers unquote(opts[:headers]) || []
      @allow   unquote(opts[:allow]) || false

      @before_compile unquote(__MODULE__)

      @resource  false
      @endpoint  Stack.Simple.new
      @endpoints HashDict.new
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
      def handle("OPTIONS", URI.Info[path: path], req) do
        endpoint = Enum.find @endpoints, fn { endpoint, methods } ->
          path |> String.starts_with? endpoint
        end

        if endpoint do
          if @allow do
            methods = Enum.map(elem(endpoint, 1), fn
              { name, _ } -> name
              name        -> name
            end) |> Enum.uniq

            headers = prepare_headers(req.headers)
            headers = headers |> Dict.put("Access-Control-Allow-Methods", Enum.join(methods, ", "))

            req.reply(200, headers, "")
          else
            req.reply(405)
          end
        else
          req.reply(404)
        end
      end

      def handle(_, URI.Info[path: path], req) do
        endpoint = Enum.find @endpoints, fn { endpoint, methods } ->
          path |> String.starts_with? endpoint
        end

        if endpoint do
          req.reply(405)
        else
          req.reply(404)
        end
      end

      def endpoints do
        @endpoints
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

      @path endpoint_to_path(@endpoint)
      @endpoints Dict.put(@endpoints, @path, [])

      unquote(body)

      @endpoint Stack.pop(@endpoint) |> elem(1)
      @resource false
    end
  end

  defmacro verb(name, do: body) do
    quote bind_quoted: [method: to_string(name) |> String.upcase, body: Macro.escape(body)] do
      unless @resource do
        raise ArgumentError, message: "cannot define standalone verb outside a resource"
      end

      @path endpoint_to_path(@endpoint)

      if Enum.find(@endpoints[@path], fn
        ^method -> true
        _       -> false
      end) do
        raise ArgumentError, message: "#{method} already defined"
      end

      @endpoints Dict.update(@endpoints, @path, fn endpoint ->
        [method | endpoint]
      end)

      def handle(unquote(method), URI.Info[path: @path] = uri, req) do
        body_to_response unquote(body)
      end
    end
  end

  defmacro verb(name, path, do: body) when path |> is_atom do
    quote bind_quoted: [method: to_string(name) |> String.upcase, path: to_string(path), body: Macro.escape(body)] do
      if @resource do
        raise ArgumentError, "cannot define standalone verb inside a resource"
      end

      @path endpoint_to_path(@endpoint)

      def handle(unquote(method), URI.Info[path: @path <> "/" <> unquote(path)] = uri, req) do
        body_to_response unquote(body)
      end
    end
  end

  defmacro verb(name, { id, _, _ } = variable, do: body) do
    quote bind_quoted: [method: to_string(name) |> String.upcase, id: id, variable: Macro.escape(variable), body: Macro.escape(body)] do
      unless @resource do
        raise ArgumentError, message: "cannot define standalone verb outside a resource"
      end

      @path endpoint_to_path(@endpoint)

      if Enum.find(@endpoints[@path], fn
        { ^method, _ } -> true
        _              -> false
      end) do
        raise ArgumentError, message: "#{method}/#{id} already defined"
      end

      @endpoints Dict.update(@endpoints, @path, fn endpoint ->
        [{ method, id } | endpoint]
      end)

      def handle(unquote(method), URI.Info[path: @path <> "/" <> unquote(variable)] = uri, req) do
        body_to_response unquote(body)
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
            JSON.decode(content)

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
            { code } when code |> is_integer or code |> is_tuple  ->
              req.reply(code, prepare_headers(req.headers), "")

            { code, headers } when code |> is_integer or code |> is_tuple ->
              req.reply(code, prepare_headers(req.headers, headers), "")

            result ->
              req.reply(200, prepare_headers(req.headers, [{ "Content-Type", "application/json" }]),
                JSON.encode!(result))
          end

        { :error, _ } ->
          req.reply(406, prepare_headers(req.headers), "")
      end
    end
  end

  defmacro prepare_headers(request) do
    quote do
      Urna.prepare_headers(@allow, unquote(request), @headers, [])
    end
  end

  defmacro prepare_headers(request, user) do
    quote do
      Urna.prepare_headers(@allow, unquote(request), @headers, unquote(user))
    end
  end

  def prepare_headers(allow, request, default, user) do
    headers = Dict.merge(default, user)

    if allow do
      unless headers |> Dict.has_key?("Access-Control-Allow-Origin") do
        case allow[:origins] do
          nil ->
            headers = headers |> Dict.put("Access-Control-Allow-Origin",
              Dict.get(request, "Origin", "*"))

          list when list |> is_list ->
            origin = Dict.get(request, "Origin")

            if Enum.member?(list, origin) do
              headers = headers |> Dict.put("Access-Control-Allow-Origin", origin)
            end
        end
      end

      unless headers |> Dict.has_key?("Access-Control-Allow-Headers") do
        case allow[:headers] do
          true ->
            headers = headers |> Dict.put("Access-Control-Allow-Headers",
              Dict.get(request, "Access-Control-Request-Headers", "*"))

          list when list |> is_list ->
            headers = headers |> Dict.put("Access-Control-Allow-Headers", Enum.join(list, ", "))

          _ ->
            nil
        end
      end

      unless headers |> Dict.has_key?("Access-Control-Allow-Methods") do
        case allow[:methods] do
          true ->
            headers = headers |> Dict.put("Access-Control-Allow-Methods",
              Dict.get(request, "Access-Control-Request-Method", "*"))

          list when list |> is_list ->
            headers = headers |> Dict.put("Access-Control-Allow-Methods", Enum.join(list, ", "))

          _ ->
            nil
        end
      end

      unless headers |> Dict.has_key?("Access-Control-Allow-Credentials") do
        if allow[:credentials] do
          headers = headers |> Dict.put("Access-Control-Allow-Credentials", "true")
        end
      end
    end

    headers
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

  defmacro success(code, text) when code in 100 .. 399 and text |> is_binary do
    quote do
      { { unquote(code), unquote(text) } }
    end
  end

  defmacro success(code, headers) when code in 100 .. 399 do
    quote do
      { unquote(code), unquote(headers) }
    end
  end

  defmacro success(code, text, headers) when code in 100 .. 399 do
    quote do
      { { unquote(code), unquote(text) }, unquote(headers) }
    end
  end

  defmacro fail(code) when code in 400 .. 599 do
    quote do
      { unquote(code) }
    end
  end

  defmacro fail(code, text) when code in 400 .. 599 and text |> is_binary do
    quote do
      { { unquote(code), unquote(text) } }
    end
  end

  defmacro fail(code, headers) when code in 400 .. 599 do
    quote do
      { unquote(code), unquote(headers) }
    end
  end

  defmacro fail(code, text, headers) when code in 400 .. 599 do
    quote do
      { { unquote(code), unquote(text) }, unquote(headers) }
    end
  end

  defmacro redirect(uri) do
    quote do
      { 301, [{ "Location", to_string(unquote(uri)) }] }
    end
  end
end
