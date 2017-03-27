defmodule Urna.Mixfile do
  use Mix.Project

  def project do
    [ app: :urna,
      version: "0.1.5",
      deps: deps(),
      package: package(),
      description: "REST in peace" ]
  end

  defp package do
    [ maintainers: ["meh"],
      licenses: ["WTFPL"],
      links: %{"GitHub" => "https://github.com/meh/urna"} ]
  end

  def application do
    [ applications: [:cauldron, :jazz] ]
  end

  defp deps do
    [ { :cauldron, "~> 0.1" },
      { :jazz,     "~> 0.2" },
      { :ex_doc,   "~> 0.14", only: [:dev] } ]
  end
end
