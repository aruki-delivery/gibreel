defmodule Gibreel.Mixfile do
  use Mix.Project

  def project do
    [app: :gibreel,
      version: "4.0.0",
      language: :erlang,
      deps: deps(Mix.env()),
      description: "Distributed cache implemented in Erlang",
      package: package(),
      source_url: "https://github.com/aruki-delivery/gibreel",
      homepage_url: "https://hex.pm/packages/gibreel"]
  end

  defp deps(_) do
  [
     {:columbo, "~>1.0.0"},
     {:cclock, "~> 1.0.0"},
     {:async, "~> 0.1.0"},
     {:ex_doc, ">= 0.0.0", only: :dev}]
  end

  def package do
    [ maintainers: ["cblage"],
      licenses: ["Apache License 2.0"],
      links: %{"GitHub" => "https://github.com/aruki-delivery/gibreel" } ]
  end
end