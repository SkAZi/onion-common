defmodule OnionCommon.Mixfile do
  use Mix.Project

  def project do
    [app: :onion_common,
     version: "0.1.0",
     elixir: "~> 1.0.0",
     deps: deps]
  end

  def application do
    [applications: [:onion]]
  end

  defp deps do
    [
      {:onion, git: "https://github.com/veryevilzed/onion"},
      {:jiffy , git: "https://github.com/SkAZi/jiffy"}
    ]
  end
end
