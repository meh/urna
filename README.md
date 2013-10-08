Urna - REST in peace
====================
Urna is a simple DSL around [cauldron](https://github.com/meh/cauldron) to
implement REST services.

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
