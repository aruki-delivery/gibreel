defmodule GibReel.Mixfile do
  use Mix.Project

  def project do
    [app: :gibreel,
      version: "1.1.0",
      deps: deps(Mix.env()),
      description: "Distributed cache implemented in Elixir / Erlang",
      package: package(),
      source_url: "https://github.com/aruki-delivery/gibreel",
      homepage_url: "https://hex.pm/packages/gibreel"]
  end

  defp deps(_) do
    [{:columbo, "~> 0.1.0"},
     {:cclock, "~> 0.1.0"},
     {:async, "~> 0.1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev}]
  end
  def application do
    [mod: {Gibreel.Application, []},
      extra_applications: [:logger, :columbo],]
  end

  def package do
    [ maintainers: ["cblage"],
      licenses: ["Apache License 2.0"],
      links: %{"GitHub" => "https://github.com/aruki-delivery/gibreel" } ]
  end
end