defmodule Urna.Mixfile do
  use Mix.Project

  def project do
    [ app: :urna,
      version: "0.1.0",
      elixir: "~> 0.13.2",
      deps: deps,
      package: package,
      description: "REST in peace" ]
  end

  defp package do
    [ contributors: ["meh"],
      license: ["WTFPL"],
      links: [ { "GitHub", "https://github.com/meh/urna" } ] ]
  end

  def application do
    [ applications: [:cauldron, :jazz] ]
  end

  defp deps do
    [ { :cauldron, "~> 0.1.0" },
      { :jazz, "~> 0.1.0" } ]
  end
end
