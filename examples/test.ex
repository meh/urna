defmodule Test do
  use Urna,
    allow:    [headers: true, methods: true, credentials: true],
    adapters: [Urna.JSON, Urna.Form]

  namespace :foo do
    resource :bar do
      post do
        param("id")
      end

      get do
        fail 500, "herp"
      end

      get id, as: Integer do
        case id do
          42 ->
            %{id: id, name: "John"}

          23 ->
            { Poison.encode! %{id: id, name: "Richard"} }

          true ->
            fail 406
        end
      end

      put _id do
        param("name")
      end
    end
  end

  namespace :bar do
    get :baz do
      "lol"
    end
  end
end

# c("examples/test.ex"); Urna.start Test, port: 8080
