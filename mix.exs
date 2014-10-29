defmodule OnionCommon.Mixfile do
  use Mix.Project

  def project do
    [app: :onion_common,
     version: "0.0.1",
     elixir: "~> 1.0.0",
     deps: deps]
  end

  def application do
    [applications: [:onion]]
  end

  defp deps do
    [
      {:onion, github: "veryevilzed/onion"},
      {:jiffy , github: "davisp/jiffy"},
      {:underscorex, github: "veryevilzed/underscorex"}
    ]
  end
end
