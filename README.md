Urna - REST in peace
====================
*Urna* is a simple DSL around [cauldron](https://github.com/meh/cauldron) to
implement REST services.

Basics
------
*Urna* tries to follow the REST style as closely as possible, there are
namespaces and resources, and standard requests to these resources will receive
proper answers.

It includes `OPTIONS` requests being properly processed, requests on non-existent
resources being answered with `404` and verbs not implemented for the resource being
answered with a `405`.

```elixir
defmodule Example do
  use Urna

  # namespace is used to define an additional path to access the resource, in
  # this case /foo/.
  namespace :foo do
    # resource is used to, you guessed it, define a resource, since we're in
    # the :foo namespace it will be accessible at /foo/bar.
    resource :bar do
      # A get without a parameter responds to a GET request to the resource, in
      # this case /foo/bar.
      #
      # The result of the block is automatically converted to an accepted
      # content type extracted from the Accept header.
      get do
        42
      end

      # A get with a parameter responds to a GET request to the resource with
      # an additional value, in this case /foo/bar/:id.
      get id do
        id
      end

      # A post without a parameter, alike get, responds to a POST request to
      # the resource, again in this case /foo/bar.
      #
      # You can access the decoded content in the params variable, the decoding
      # is done based on the Content-Type header assumed there's an available
      # decoder for that type.
      post do
        params["id"]
      end

      # Other common verbs are available: head, get, post, put, delete.
      #
      # If you want you can define your own verbs too, instead of using the
      # available ones you can use the verb function.
      #
      # In this case it will respond to a HUE request on /foo/bar.
      verb "HUE" do
        "huehuehuehue"
      end
    end
  end
end
```

Replying to or failing the request
----------------------------------
Sometimes you want to answer with a failure or a success with a specific
response code and text.

To do this you can use the `reply` and `fail` functions. Both functions take as
first parameter the error code, unless a text parameter is given it will use
the standard text.

If a result is also given, it's expected as first parameter.

```elixir
defmodule Example do
  use Urna

  resource :foo do
    # I'm a tea pot.
    get do
      fail 418
    end
  end

  resource :bar do
    # Here you could do something with the parameters and write a row to a
    # table, so you'd want to answer to the request with a 201 (Created)
    # response, on top with the newly created row.
    post do
      Hey.create(params) |> reply 201
    end
  end
end
```

Verb parameter conversion
-------------------------
*Urna* also supports converting the verb parameter to an `integer` or `float`,
for more complex conversion you'll have to deal it yourself.

```elixir
defmodule Example do
  use Urna

  resource :baz do
    get id, as: Integer do

    end
  end
end
```

Accessing various variables
---------------------------
On top of `params` there are other useful variables you can access.

* `headers` contains the headers of the request.
* `uri` is the `URI.Info` of the request.
* `query` is the decoded query part of the uri.

Adapters
--------
*Urna* supports various adapters and it's easy to extend them as well.

Adapters are used to deal with encoding and decoding based on the value of
`Accept` and `Content-Type` headers.

The ones provided out of the box are an `application/json` adapter based on
[jazz](https://github.com/meh/jazz) and an `application/x-www-form-urlencoded`
adapter which uses the standard `URI.decode_query` function.

```elixir
defmodule Example do
  use Urna, adapters: [Urna.JSON, Urna.Form]

  resource :foo do
    get do
      [foo: :bar]
    end
  end
end
```

CORS
----
*Urna* supports CORS out of the box, just pass what to allow on `use Urna` and
it will handle the various access control headers automatically.

```elixir
defmodule API do
  use Urna, allow: [methods: true, headers: true, credentials: true]
end
```

This example will allow all methods, headers and HTTP credentials, check the
documentation for more information.


Deploying on Heroku
-------------------

Give an app (mix is required):

```elixir
defmodule TestApp do
  use Urna

  resource "", do: "hello world!"
end
```


Create an app with the elixir buildpack:

    heroku create --buildpack https://github.com/HashNuke/heroku-buildpack-elixir.git


Add a `Procfile` with the following line:

    web: mix run -e "{:ok,_} = Urna.start TestApp, port: ${PORT:-3000}" --no-halt


Push the app to deploy it:

    git push heroku master
