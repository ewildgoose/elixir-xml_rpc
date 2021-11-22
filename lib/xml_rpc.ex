defmodule XMLRPC do
  alias XMLRPC.DecodeError
  alias XMLRPC.EncodeError
  alias XMLRPC.Decoder
  alias XMLRPC.Encoder


  @moduledoc ~S"""
  Encode and decode elixir terms to [XML-RPC](http://wikipedia.org/wiki/XML-RPC) parameters.
  All XML-RPC parameter types are supported, including arrays, structs and Nil (optional).

  This module handles the parsing and encoding of the datatypes, but can be used
  in conjunction with HTTPoison, Phoenix, etc to create fully featured XML-RPC
  clients and servers.

  XML input (ie untrusted) is validated against an [XML Schema](http://en.wikipedia.org/wiki/XML_schema),
  which should help enforce correctness of input.  [erlsom](https://github.com/willemdj/erlsom)
  is used to decode the xml as xmerl creates atoms during decoding, which has
  the risk that a malicious client can exhaust out atom space and crash the vm.

  ## Example

      iex> _request_body = %XMLRPC.MethodCall{method_name: "test.sumprod", params: [2,3]} |> XMLRPC.encode!
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?><methodCall><methodName>test.sumprod</methodName><params><param><value><int>2</int></value></param><param><value><int>3</int></value></param></params></methodCall>"

      # Now use HTTPoison to call your RPC
      response = HTTPoison.post!("http://www.advogato.org/XMLRPC", request_body).body

      iex> _response = "<?xml version=\"1.0\"?><methodResponse><params><param><value><array><data><value><int>5</int></value><value><int>6</int></value></data></array></value></param></params></methodResponse>" |> XMLRPC.decode
      {:ok, %XMLRPC.MethodResponse{param: [5, 6]}}


  ## Datatypes

  XML-RPC only allows limited parameter types. We map these to Elixir as follows:

  | XMLRPC               | Elixir                    |
  | ---------------------|---------------------------|
  | `<boolean>`          | Boolean, eg true/false    |
  | `<string>`           | Bitstring, eg "string"    |
  | `<int>` (`<i4>`)     | Integer, eg 17            |
  | `<double>`           | Float, eg -12.3           |
  | `<array>`            | List, eg [1, 2, 3]        |
  | `<struct>`           | Map, eg %{key: "value"}   |
  | `<dateTime.iso8601>` | %XMLRPC.DateTime          |
  | `<base64>`           | %XMLRPC.Base64            |
  | `<nil/>` (optional)  | nil                       |

  Note that array and struct parameters can be composed of the fundamental types,
  and you can nest to arbitrary depths. (int inside a struct, inside an array, inside a struct, etc).
  Common practice seems to be to use a struct (or sometimes an array) as the top
  level to pass (named) each way.

  The XML encoding is performed through a protocol and so abstract datatypes
  can be encoded by implementing the `XMLRPC.ValueEncoder` protocol.

  ### Nil
  Nil is not defined in the core specification, but is commonly implemented as
  an option.  The use of nil is enabled by default for encoding and decoding.
  If you want a <nil/> input to be treated as an error then pass
  [exclude_nil: true] in the `options` parameter


  ## API

  The XML-RPC api consists of a call to a remote url, passing a "method_name"
  and a number of parameters.

      %XMLRPC.MethodCall{method_name: "test.sumprod", params: [2,3]}

  The response is either "failure" and a `fault_code` and `fault_string`, or a
  response which consists of a single parameter (use a struct/array to pass back
  multiple values)

      %XMLRPC.Fault{fault_code: 4, fault_string: "Too many parameters."}

      %XMLRPC.MethodResponse{param: 30}

  To encode/decode to xml use `XMLRPC.encode/2` or `XMLRPC.decode/2`

  ### Options
  The en/decoder take an array of options:

  * `:iodata` - When false (default), converts output of encoder to a string
  * `:exclude_nil` - When false (default), allows nil to be a valid type in encoder/decoder

  """

  defmodule Fault do
    @moduledoc """
    struct defining an xml-rpc 'fault' response
    """
    @type t :: %__MODULE__{fault_code: Integer, fault_string: String.t}

    defstruct fault_code: 0, fault_string: ""
  end

  defmodule MethodCall do
    @moduledoc """
    struct defining an xml-rpc call (note array of params)
    """
    @type t :: %__MODULE__{method_name: String.t, params: [ XMLRPC.t ]}

    defstruct method_name: "", params: nil
  end

  defmodule MethodResponse do
    @moduledoc """
    struct defining an xml-rpc response (note single param)
    """
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

  @doc ~S"""
  Encode an XMLRPC call or response elixir structure into XML.

  Raises an exception on error.

    iex> %XMLRPC.MethodCall{method_name: "test.sumprod", params: [2,3]} |> XMLRPC.encode!
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?><methodCall><methodName>test.sumprod</methodName><params><param><value><int>2</int></value></param><param><value><int>3</int></value></param></params></methodCall>"

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

  @doc ~S"""
  Encode an XMLRPC call or response elixir structure into XML.

      iex> %XMLRPC.MethodCall{method_name: "test.sumprod", params: [2,3]} |> XMLRPC.encode
      {:ok, "<?xml version=\"1.0\" encoding=\"UTF-8\"?><methodCall><methodName>test.sumprod</methodName><params><param><value><int>2</int></value></param><param><value><int>3</int></value></param></params></methodCall>"}

  """
  @spec encode(XMLRPC.t, Keyword.t) :: {:ok, iodata} | {:ok, String.t} | {:error, {any, String.t}}
  def encode(value, options \\ []) do
    {:ok, encode!(value, options)}

  rescue
    exception in [EncodeError] ->
      {:error, {exception.value, exception.message}}
  end


  @doc ~S"""
  Decode XMLRPC call or response XML into an Elixir structure

      iex> XMLRPC.decode("<?xml version=\"1.0\"?><methodResponse><params><param><value><array><data><value><int>5</int></value><value><int>6</int></value></data></array></value></param></params></methodResponse>")
      {:ok, %XMLRPC.MethodResponse{param: [5, 6]}}

  """
  @spec decode(iodata, Keyword.t) :: {:ok, Fault.t} | {:ok, MethodCall.t} | {:ok, MethodResponse.t} | {:error, String.t}
  def decode(value, options \\ []) do
    {:ok, decode!(value, options)}

  rescue
    exception in [DecodeError] ->
      {:error, exception.message}
  end

  @doc ~S"""
  Decode XMLRPC call or response XML into an Elixir structure

  Raises an exception on error.

      iex> XMLRPC.decode!("<?xml version=\"1.0\"?><methodResponse><params><param><value><array><data><value><int>5</int></value><value><int>6</int></value></data></array></value></param></params></methodResponse>")
      %XMLRPC.MethodResponse{param: [5, 6]}

  """
  @spec decode!(iodata, Keyword.t) :: Fault.t | MethodCall.t | MethodResponse.t | no_return
  def decode!(value, options \\ []) do
    Decoder.decode!(value, options)
  end
end
