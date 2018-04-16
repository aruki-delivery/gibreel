defmodule Gibreel.Mixfile do
  use Mix.Project

  def project do
    [app: :gibreel,
      version: "5.0.1",
      language: :erlang,
      deps: deps(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test],
      description: "Distributed cache implemented in Elixir / Erlang",
      package: package(),
      source_url: "https://github.com/aruki-delivery/gibreel",
      homepage_url: "https://hex.pm/packages/gibreel"]
  end

  defp deps(_) do
  [
     {:columbo, "~> 2.0.0"},
     {:cclock, "~> 2.0.0"},
     {:async, "~> 2.0.0"},
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
