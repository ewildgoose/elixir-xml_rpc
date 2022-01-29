defmodule XmlRpc.Mixfile do
  use Mix.Project

  @source_url "https://github.com/ewildgoose/elixir-xml_rpc"
  @version "1.4.2"

  def project do
    [
      app: :xmlrpc,
      version: @version,
      elixir: "~> 1.4",
      name: "XMLRPC",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:erlsom, "~> 1.4"},
      {:decimal, "~> 1.0"}
    ]
  end

  defp package do
    [
      description:
        "XML-RPC encoder/decder for Elixir. Supports all valid " <>
          "datatypes. Input (ie untrusted) is parsed with erlsom against " <>
          "an xml-schema for security.",
      files: ~w(lib mix.exs README.md LICENSE),
      maintainers: ["Ed Wildgoose"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      extras: [
        LICENSE: [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "master",
      formatters: ["html"]
    ]
  end
end
