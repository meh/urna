Urna - REST in peace
====================
Urna is a simple DSL around [cauldron](https://github.com/meh/cauldron) to
implement REST services.

Basics
------
*Urna* tries to follow the REST style as closely as possible, there are
namespaces and resources, and standard requests to these resources will receive
proper answers.

These includes `OPTIONS` requests being properly processed, requests on non-existent
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

CORS
----
Urna supports CORS out of the box, just pass what to allow when using Urna and
it will handle the various access control headers automatically.

```elixir
defmodule API do
  use Urna, allow: [methods: true, headers: true, credentials: true]
end
```

This example will allow all methods, headers and HTTP credentials, check the
documentation for more information.
