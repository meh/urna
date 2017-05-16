defmodule Urna.Mixfile do
  use Mix.Project

  def project do
    [ app: :urna,
      version: "0.2.3",
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
    [ extra_applications: [:logger] ]
  end

  defp deps do
    [ { :cauldron, "~> 0.1" },
      { :poison,   "~> 3.0" },
      { :ex_doc,   "~> 0.14", only: [:dev] } ]
  end
end
