#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule Urna do
  def start(what, listener) do
    Cauldron.start what, listener
  end

  def start_link(what, listener) do
    Cauldron.start_link what, listener
  end

  @doc """
  Make the DSL available to the module.

  ## Options

  * `:headers` - default headers to send with every response
  * `:allow`   - CORS rules for what to allow
    - `:origins`     - list of origins to allow
    - `:methods`     - list of methods to allow or `true` to allow any method
    - `:headers`     - list of headers to allow or `true` to allow any header
    - `:credentials` - whether to allow credentials or not
  * `:adapters` - list of adapters, defaults to [Urna.JSON]

  """
  defmacro __using__(opts) do
    quote do
      use Cauldron
      import Urna

      @headers  unquote(opts[:headers]) || %{}
      @allow    unquote(opts[:allow]) || false
      @adapters unquote(opts[:adapters]) || [Urna.JSON]

      @before_compile unquote(__MODULE__)

      @resource  false
      @endpoint  []
      @endpoints %{}
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
      def handle("OPTIONS", %URI{path: path}, req) do
        alias Cauldron.Request, as: R

        endpoint = Enum.find @endpoints, fn { endpoint, methods } ->
          path |> String.starts_with? endpoint
        end

        if endpoint do
          if @allow do
            methods = Enum.map(elem(endpoint, 1), fn
              { name, _ } -> name
              name        -> name
            end) |> Enum.uniq

            headers = Urna.Backend.headers(@allow, req |> R.headers, @headers, %{})
            headers = headers |> Dict.put("Access-Control-Allow-Methods", Enum.join(methods, ", "))

            req |> R.reply(200, headers, "")
          else
            req |> R.reply(405)
          end
        else
          req |> R.reply(404)
        end
      end

      def handle(_, %URI{path: path}, req) do
        alias Cauldron.Request, as: R

        endpoint = Enum.find @endpoints, fn { endpoint, methods } ->
          path |> String.starts_with? endpoint
        end

        if endpoint do
          req |> R.reply(405)
        else
          req |> R.reply(404)
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

      @endpoint [to_string(unquote(name)) | @endpoint]

      unquote(body)

      @endpoint tl(@endpoint)
    end
  end

  defmacro resource(name \\ "", do: body) do
    quote do
      @resource true
      @endpoint [to_string(unquote(name)) | @endpoint]

      @path endpoint_to_path(@endpoint)
      @endpoints Dict.put(@endpoints, @path, [])

      unquote(body)

      @endpoint tl(@endpoint)
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
        meth when meth == method -> true
        _                        -> false
      end) do
        raise ArgumentError, message: "#{method} already defined"
      end

      @endpoints Dict.update!(@endpoints, @path, fn endpoint ->
        [method | endpoint]
      end)

      def handle(unquote(method), %URI{path: @path} = var!(uri, Urna), var!(req, Urna)) do
        body_to_response unquote(body)
      end
    end
  end

  defmacro verb(name, path, do: body) when path |> is_atom or path |> is_binary do
    quote bind_quoted: [method: to_string(name) |> String.upcase, path: to_string(path), body: Macro.escape(body)] do
      if @resource do
        raise ArgumentError, "cannot define standalone verb inside a resource"
      end

      @path endpoint_to_path(@endpoint)

      def handle(unquote(method), %URI{path: @path <> "/" <> unquote(path)} = var!(uri, Urna), var!(req, Urna)) do
        body_to_response unquote(body)
      end
    end
  end

  defmacro verb(name, { _, _, _ } = variable, do: body) do
    quote do
      verb(unquote(name), unquote(variable), [], do: unquote(body))
    end
  end

  defmacro verb(name, { id, _, _ } = variable, options, do: body) do
    quote bind_quoted: [method: to_string(name) |> String.upcase, id: id, variable: Macro.escape(variable), options: options, body: Macro.escape(body)] do
      unless @resource do
        raise ArgumentError, message: "cannot define standalone verb outside a resource"
      end

      @path endpoint_to_path(@endpoint)

      if Enum.find(@endpoints[@path], fn
        { meth, _ } when meth == method -> true
        _                               -> false
      end) do
        raise ArgumentError, message: "#{method}/#{id} already defined"
      end

      @endpoints Dict.update!(@endpoints, @path, fn endpoint ->
        [{ method, id } | endpoint]
      end)

      case options[:as] do
        as when as in [nil, String] ->
          def handle(unquote(method), %URI{path: @path <> "/" <> unquote(variable)} = var!(uri, Urna), var!(req, Urna)) do
            body_to_response unquote(body)
          end

        Integer ->
          def handle(unquote(method), %URI{path: @path <> "/" <> unquote(variable)} = var!(uri, Urna), var!(req, Urna)) do
            unquote(variable) = unquote(variable) |> Integer.parse |> elem(0)

            body_to_response unquote(body)
          end

        Float ->
          def handle(unquote(method), %URI{path: @path <> "/" <> unquote(variable)} = var!(uri, Urna), var!(req, Urna)) do
            unquote(variable) = unquote(variable) |> Float.parse |> elem(0)

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

    defmacro unquote(name)(variable, options, do: body) do
      method = unquote(method)

      quote do
        verb(unquote(method), unquote(variable), unquote(options), do: unquote(body))
      end
    end
  end

  @doc false
  def endpoint_to_path(stack) do
    "/" <> (stack |> Enum.reverse |> Enum.join("/"))
  end

  @doc false
  defmacro body_to_response(body) do
    quote do
      case Urna.Backend.decode(var!(req, Urna), @adapters) do
        { :ok, var!(params, Urna) } ->
          Urna.Backend.ok(var!(req, Urna), unquote(body), @adapters, @allow, @headers)

        { :error, _ } ->
          Urna.Backend.error(var!(req, Urna), @allow, @headers)
      end
    end
  end

  defmacro headers do
    quote do: var!(req, Urna).headers
  end

  defmacro params do
    quote do: var!(params, Urna)
  end

  defmacro uri do
    quote do: var!(uri, Urna)
  end

  defmacro query do
    quote do: URI.decode_query(var!(uri, Urna).query)
  end

  def reply(code) when code in 100 .. 399 do
    { code }
  end

  def reply(code, text) when code in 100 .. 399 and text |> is_binary do
    { { code, text } }
  end

  def reply(code, headers) when code in 100 .. 399 do
    { code, headers }
  end

  def reply(result, code) when code in 100 .. 399 do
    { code, %{}, result }
  end

  def reply(code, text, headers) when code in 100 .. 399 and text |> is_binary do
    { { code, text }, headers }
  end

  def reply(result, code, text) when code in 100 .. 399 and text |> is_binary do
    { { code, text }, %{}, result }
  end

  def reply(result, code, headers) when code in 100 .. 399 do
    { code, headers, result }
  end

  def reply(result, code, text, headers) when code in 100 .. 399 and text |> is_binary do
    { { code, text }, headers, result }
  end

  def fail(code) when code in 400 .. 599 do
    { code }
  end

  def fail(code, text) when code in 400 .. 599 and text |> is_binary do
    { { code, text } }
  end

  def fail(code, headers) when code in 400 .. 599 do
    { code, headers }
  end

  def fail(result, code) when code in 400 .. 599 do
    { code, %{}, result }
  end

  def fail(code, text, headers) when code in 400 .. 599 and text |> is_binary do
    { { code, text }, headers }
  end

  def fail(result, code, text) when code in 400 .. 599 and text |> is_binary do
    { { code, text }, %{}, result }
  end

  def fail(result, code, headers) when code in 400 .. 599 do
    { code, headers, result }
  end

  def fail(result, code, text, headers) when code in 400 .. 599 and text |> is_binary do
    { { code, text }, headers, result }
  end

  def redirect(uri) do
    { 301, [{ "Location", to_string(uri) }] }
  end
end
