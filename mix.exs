defmodule Urna.Mixfile do
  use Mix.Project

  def project do
    [ app: :urna,
      version: "0.0.1",
      elixir: "~> 0.13.2-dev",
      deps: deps ]
  end

  defp deps do
    [ { :cauldron, github: "meh/cauldron" },
      { :jazz, "~> 0.1.0" } ]
  end
end
