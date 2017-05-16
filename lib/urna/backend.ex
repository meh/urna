defmodule Urna.Backend do
  use Data

  alias HTTProt.Headers
  alias Cauldron.Request

  def decode(req, adapters) do
    [type | _] = req
      |> Request.headers
      |> Dict.get("Content-Type", "")
      |> String.split("; ")

    adapter = Enum.find adapters, &(&1.accept?(type))
    body    = req |> Request.body

    cond do
      adapter && body ->
        adapter.decode(type, body)

      body ->
        { :error, :unsupported_content_type }

      true ->
        { :ok, nil }
    end
  end

  def headers(allow, request, default, user) do
    headers = Dict.merge(default, user) |> Enum.into(Headers.new)

    if allow do
      headers = unless headers |> Dict.has_key?("Access-Control-Allow-Origin") do
        case allow[:origins] do
          nil ->
            headers |> Dict.put("Access-Control-Allow-Origin",
              Dict.get(request, "Origin", "*"))

          list when list |> is_list ->
            origin = Dict.get(request, "Origin")

            if Enum.member?(list, origin) do
              headers |> Dict.put("Access-Control-Allow-Origin", origin)
            else
              headers
            end

          _ ->
            headers
        end
      else
        headers
      end

      headers = unless headers |> Dict.has_key?("Access-Control-Allow-Headers") do
        case allow[:headers] do
          true ->
            headers |> Dict.put("Access-Control-Allow-Headers",
              Dict.get(request, "Access-Control-Request-Headers", "*"))

          list when list |> is_list ->
            headers |> Dict.put("Access-Control-Allow-Headers",
              Enum.join(list, ", "))

          _ ->
            headers
        end
      else
        headers
      end

      headers = unless headers |> Dict.has_key?("Access-Control-Allow-Methods") do
        case allow[:methods] do
          true ->
            headers |> Dict.put("Access-Control-Allow-Methods",
              Dict.get(request, "Access-Control-Request-Method", "*"))

          list when list |> is_list ->
            headers |> Dict.put("Access-Control-Allow-Methods", Enum.join(list, ", "))

          _ ->
            headers
        end
      else
        headers
      end

      headers = unless headers |> Dict.has_key?("Access-Control-Allow-Credentials") do
        if allow[:credentials] do
          headers |> Dict.put("Access-Control-Allow-Credentials", "true")
        else
          headers
        end
      end

      headers
    else
      headers
    end
  end

  def response(adapters, request, result) do
    { mime, adapter } = case request["Accept"] do
      nil ->
        { nil, hd(adapters) }

      [{ "*/*", _ }] ->
        { nil, hd(adapters) }

      [{ name, _ }] ->
        { name, Enum.find(adapters, &(&1.accept?(name))) }

      accept ->
        accepted = accept |> Enum.group_by(&elem(&1, 1)) |> Enum.sort(&(elem(&1, 0) > elem(&2, 0)))
          |> Enum.find_value(fn { _, types } ->
            Enum.find_value types, fn { name, _ } ->
              if adapter = Enum.find adapters, &(&1.accept?(name)) do
                { name, adapter }
              end
            end
          end)

        cond do
          accepted ->
            accepted

          Enum.find accept, &match?({ "*/*", _ }, &1) ->
            { nil, hd(adapters) }

          true ->
            { nil, nil }
        end
    end

    if adapter do
      adapter.encode(mime, result)
    end
  end

  def ok(req, res, adapters!, allow!, headers!) do
    case res do
      { result } when result |> is_binary ->
        req |> Request.reply(200, headers(allow!, req |> Request.headers, headers!, %{}), result)

      { code, result } when (code |> is_integer or code |> is_tuple) and result |> is_binary ->
        req |> Request.reply(code, headers(allow!, req |> Request.headers, headers!, %{}), result)

      { code, headers, result } when (code |> is_integer or code |> is_tuple) and result |> is_binary ->
        req |> Request.reply(code, headers(allow!, req |> Request.headers, headers!, headers), result)

      { code } when code |> is_integer or code |> is_tuple  ->
        req |> Request.reply(code, headers(allow!, req |> Request.headers, headers!, %{}), "")

      { code, headers } when code |> is_integer or code |> is_tuple ->
        req |> Request.reply(code, headers(allow!, req |> Request.headers, headers!, headers), "")

      { code, headers, result } when code |> is_integer or code |> is_tuple ->
        case response(adapters!, req |> Request.headers, result) do
          { type, response } ->
            req |> Request.reply(code,
              headers(allow!, req |> Request.headers, headers!, Dict.put(headers, "Content-Type", type)),
              response)

          nil ->
            req |> Request.reply(406, headers(allow!, req |> Request.headers, headers!, headers), "")
        end

      result ->
        case response(adapters!, req |> Request.headers, result) do
          { type, response } ->
            req |> Request.reply(200,
              headers(allow!, req |> Request.headers, headers!, %{"Content-Type" => type}),
              response)

          nil ->
            req |> Request.reply(406, headers(allow!, req |> Request.headers, headers!, %{}), "")
        end
    end
  end

  def error(req, allow!, headers!) do
    req |> Request.reply(406, headers(allow!, req |> Request.headers, headers!, %{}), "")
  end

  def crash(req, error, allow!, headers!) do
    req |> Request.reply(500, headers(allow!, req |> Request.headers, headers!, %{"Content-Type": "text/plain"}),
      if(Mix.env == :prod, do: "", else: Exception.format(:error, error)))
  end
end
