defmodule Urna.Mixfile do
  use Mix.Project

  def project do
    [ app: :urna,
      version: "0.0.1",
      elixir: "~> 0.9.4-dev",
      deps: deps ]
  end

  # Configuration for the OTP application
  def application do
    []
  end

  # Returns the list of dependencies in the format:
  # { :foobar, "0.1", git: "https://github.com/elixir-lang/foobar.git" }
  defp deps do
    [ { :cauldron, github: "meh/cauldron" },
      { :jsex, github: "talentdeficit/jsex" } ]
  end
end
