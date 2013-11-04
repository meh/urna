defmodule Urna.Backend do
  alias Data.Seq
  alias Data.Dict

  def decode(req, adapters) do
    type    = req.headers["Content-Type"]
    adapter = Seq.find adapters, &(&1.accept?(type))
    body    = req.body

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
    headers = Dict.merge(default, user)

    if allow do
      unless headers |> Dict.has_key?("Access-Control-Allow-Origin") do
        case allow[:origins] do
          nil ->
            headers = headers |> Dict.put("Access-Control-Allow-Origin",
              Dict.get(request, "Origin", "*"))

          list when list |> is_list ->
            origin = Dict.get(request, "Origin")

            if Data.contains?(list, origin) do
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
            headers = headers |> Dict.put("Access-Control-Allow-Headers", Seq.join(list, ", "))

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
            headers = headers |> Dict.put("Access-Control-Allow-Methods", Seq.join(list, ", "))

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

  def response(adapters, request, result) do
    { mime, adapter } = case request["Accept"] do
      nil ->
        { nil, hd(adapters) }

      [{ "*/*", _ }] ->
        { nil, hd(adapters) }

      [{ name, _ }] ->
        { name, Seq.find(adapters, &(&1.accept?(name))) }

      accept ->
        accepted = accept |> Seq.group_by(&elem(&1, 1)) |> Seq.sort(&(elem(&1, 0) > elem(&2, 0)))
          |> Seq.find_value(fn { _, types } ->
            Seq.find_value types, fn { name, _ } ->
              if adapter = Seq.find adapters, &(&1.accept?(name)) do
                { name, adapter }
              end
            end
          end)

        cond do
          accepted ->
            accepted

          Seq.find accept, &match?({ "*/*", _ }, &1) ->
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
      { code } when code |> is_integer or code |> is_tuple  ->
        req.reply(code, headers(allow!, req.headers, headers!, []), "")

      { code, headers } when code |> is_integer or code |> is_tuple ->
        req.reply(code, headers(allow!, req.headers, headers!, headers), "")

      { code, headers, result } ->
        case response(adapters!, req.headers, result) do
          { type, response } ->
            req.reply(code,
              headers(allow!, req.headers, headers!, Dict.put(headers, "Content-Type", type)),
              response)

          nil ->
            req.reply(406, headers(allow!, req.headers, headers!, headers), "")
        end

      result ->
        case response(adapters!, req.headers, result) do
          { type, response } ->
            req.reply(200,
              headers(allow!, req.headers, headers!, [{ "Content-Type", type }]),
              response)

          nil ->
            req.reply(406, headers(allow!, req.headers, headers!, []), "")
        end
    end
  end

  def error(req, allow!, headers!) do
    req.reply(406, headers(allow!, req.headers, headers!, []), "")
  end
end
