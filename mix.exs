defmodule XmlRpc.Mixfile do
  use Mix.Project

  def project do
    [app: :xmlrpc,
     version: "1.3.0",
     elixir: "~> 1.4",
     name: "XMLRPC",
     description: "XML-RPC encoder/decder for Elixir. Supports all valid datatypes. Input (ie untrusted) is parsed with erlsom against an xml-schema for security.",
     source_url: "https://github.com/ewildgoose/elixir-xml_rpc",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     package: package()]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [extra_applications: []]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [   {:earmark, "~> 1.0", only: :docs},
        {:ex_doc, "~> 0.14", only: :docs},
        {:erlsom, "~> 1.4"},
    ]
  end

  defp package do
    [files: ~w(lib mix.exs README.md LICENSE),
     maintainers: ["Ed Wildgoose"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/ewildgoose/elixir-xml_rpc"}]
  end
end
