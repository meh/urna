defmodule Test do
  use Urna

  namespace :foo do
    resource :bar do
      post do
        params["id"]
      end

      get do
        to_binary(uri)
      end

      get id do
        if id != "42" do
          fail 406
        else
          [ id: id, name: "John" ]
        end
      end

      put id do
        params["name"]
      end
    end
  end

  namespace :bar do
    get :baz do
      "lol"
    end
  end
end
