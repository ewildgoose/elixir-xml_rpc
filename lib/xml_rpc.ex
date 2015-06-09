defmodule XMLRPC do
  alias XMLRPC.DecodeError
  alias XMLRPC.EncodeError
  alias XMLRPC.Decoder
  alias XMLRPC.Encoder


  @moduledoc ~S"""
  Encode and Decode elixir terms to [XML-RPC](http://wikipedia.org/wiki/XML-RPC) format,
  with full data-type support

  This module handles the parsing and encoding of the datatypes, but can be used
  in conjunction with HTTPoison, Phoenix, etc to create fully featured XML-RPC
  clients and servers.

  We use [erlsom](https://github.com/willemdj/erlsom) to handle the xml decoding
  as xmerl creates atoms during decoding, which has the potential that a
  malicious client can exhaust out atom space and crash the vm. Additionally
  input is parsed against an [XML Schema](http://en.wikipedia.org/wiki/XML_schema),
  which should additionally enforce correctness of input.

  ## Example

      iex> request_body = %XMLRPC.MethodCall{method_name: "test.sumprod", params: [2,3]} |> XMLRPC.encode!
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?><methodCall><methodName>test.sumprod</methodName><params><param><value><int>2</int></value></param><param><value><int>3</int></value></param></params></methodCall>"

      # Now use HTTPoison to call your RPC
      response = HTTPoison.post!("http://www.advogato.org/XMLRPC", request_body).body

      iex> response = "<?xml version=\"1.0\"?><methodResponse><params><param><value><array><data><value><int>5</int></value><value><int>6</int></value></data></array></value></param></params></methodResponse>" |> XMLRPC.decode
      {:ok, %XMLRPC.MethodResponse{param: [5, 6]}}


  ## Datatypes

  XML-RPC only allows limited parameter types. We map these to Elixir as follows:

  | XMLRPC             | Elixir                  |
  | -------------------|-------------------------|
  | <boolean>          | Boolean - true/false    |
  | <string>           | Bitstring - "string"    |
  | <int> (<i4>)       | Integer - 17            |
  | <double>`          | Float - -12.3           |
  | <array>`           | List - [1, 2, 3]        |
  | <struct>`          | Map - %{key: "value"}   |
  | <dateTime.iso8601> | %XMLRPC.DateTime        |
  | <base64>           | %XMLRPC.Base64          |
  | <nil/> (optional)  | nil                     |


  Note that array and struct parameters can be composed of the fundamental types,
  and you can nest to arbitrary depths.

  The encoding is performed through a protocol and so abstract datatypes
  can be encoded by implementing the XMLRPC.ValueEncoder protocol.
  """

  defmodule Fault do
    @type t :: %__MODULE__{fault_code: Integer, fault_string: String.t}

    defstruct fault_code: 0, fault_string: ""
  end

  defmodule MethodCall do
    @type t :: %__MODULE__{method_name: String.t, params: [ XMLRPC.t ]}

    defstruct method_name: "", params: nil
  end

  defmodule MethodResponse do
    @type t :: %__MODULE__{param: XMLRPC.t}

    defstruct param: nil
  end


  @type t :: nil | number | boolean | String.t | map() | [nil | number | boolean | String.t]


  @doc """
  Encode an XMLRPC call or response elixir structure into XML as iodata

  Raises an exception on error.
  """
  @spec encode_to_iodata!(XMLRPC.t, Keyword.t) :: {:ok, iodata} | {:error, {any, String.t}}
  def encode_to_iodata!(value, options \\ []) do
    encode!(value, [iodata: true] ++ options)
  end

  @doc """
  Encode an XMLRPC call or response elixir structure into XML as iodata
  """
  @spec encode_to_iodata(XMLRPC.t, Keyword.t) :: {:ok, iodata} | {:error, {any, String.t}}
  def encode_to_iodata(value, options \\ []) do
    encode(value, [iodata: true] ++ options)
  end

  @doc """
  Encode an XMLRPC call or response elixir structure into XML.

  Raises an exception on error.
  """
  @spec encode!(XMLRPC.t, Keyword.t) :: iodata | no_return
  def encode!(value, options \\ []) do
    iodata = Encoder.encode!(value, options)

    unless options[:iodata] do
      iodata |> IO.iodata_to_binary
    else
      iodata
    end
  end

  @doc """
  Encode an XMLRPC call or response elixir structure into XML.
  """
  @spec encode(XMLRPC.t, Keyword.t) :: {:ok, iodata} | {:ok, String.t} | {:error, {any, String.t}}
  def encode(value, options \\ []) do
    {:ok, encode!(value, options)}

  rescue
    exception in [EncodeError] ->
      {:error, {exception.value, exception.message}}
  end


  @doc """
  Decode XMLRPC call or response XML into an Elixir structure
  """
  @spec decode(iodata, Keyword.t) :: {:ok, Fault.t} | {:ok, MethodCall.t} | {:ok, MethodResponse.t} | {:error, String.t}
  def decode(value, options \\ []) do
    {:ok, decode!(value, options)}

  rescue
    exception in [DecodeError] ->
      {:error, exception.message}
  end

  @doc """
  Decode XMLRPC call or response XML into an Elixir structure

  Raises an exception on error.
  """
  @spec decode!(iodata, Keyword.t) :: Fault.t | MethodCall.t | MethodResponse.t | no_return
  def decode!(value, options \\ []) do
    Decoder.decode!(value, options)
  end
end
