XmlRpc
======

[![Build Status](https://travis-ci.org/ewildgoose/elixir-xml_rpc.svg?branch=master)](https://travis-ci.org/ewildgoose/elixir-xml_rpc)
[![Module Version](https://img.shields.io/hexpm/v/xmlrpc.svg)](https://hex.pm/packages/xmlrpc)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/xmlrpc/)
[![Total Download](https://img.shields.io/hexpm/dt/xmlrpc.svg)](https://hex.pm/packages/xmlrpc)
[![License](https://img.shields.io/hexpm/l/xmlrpc.svg)](https://github.com/ewildgoose/elixir-xml_rpc/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/ewildgoose/elixir-xml_rpc.svg)](https://github.com/ewildgoose/elixir-xml_rpc/commits/master)

Encode and decode elixir terms to [XML-RPC](http://wikipedia.org/wiki/XML-RPC) parameters.
All XML-RPC parameter types are supported, including arrays, structs and Nil (optional).

This module handles the parsing and encoding of the datatypes, but can be used
in conjunction with HTTPoison, Phoenix, etc to create fully featured XML-RPC
clients and servers.

XML input (ie untrusted) is validated against an [XML Schema](http://en.wikipedia.org/wiki/XML_schema),
which should help enforce correctness of input.  [erlsom](https://github.com/willemdj/erlsom)
is used to decode the xml as xmerl creates atoms during decoding, which has
the risk that a malicious client can exhaust out atom space and crash the vm.


## Installation

Add XML-RPC to your mix dependencies:

```elixir
def deps do
  [
    {:xmlrpc, "~> 1.3"}
  ]
end
```

Then run `mix deps.get` and `mix deps.compile`.


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

## Examples

### Client using HTTPoison

[HTTPoison](https://github.com/edgurgel/httpoison) can be used to talk to the remote API.  To encode the body we can
simply call `XMLRPC.encode/2`, and then decode the response with `XMLRPC.decode/2`

```elixir
request_body = %XMLRPC.MethodCall{method_name: "test.sumprod", params: [2,3]}
                |> XMLRPC.encode!
"<?xml version=\"1.0\" encoding=\"UTF-8\"?><methodCall><methodName>test.sumprod</methodName><params><param><value><int>2</int></value></param><param><value><int>3</int></value></param></params></methodCall>"

# Now use HTTPoison to call your RPC
response = HTTPoison.post!("http://www.advogato.org/XMLRPC", request_body).body

# eg
response = "<?xml version=\"1.0\"?><methodResponse><params><param><value><array><data><value><int>5</int></value><value><int>6</int></value></data></array></value></param></params></methodResponse>"
            |> XMLRPC.decode
{:ok, %XMLRPC.MethodResponse{param: [5, 6]}}
```
See the [HTTPoison docs](https://github.com/edgurgel/httpoison#wrapping-httpoisonbase)
for more details, but you can also wrap the base API and have HTTPoison
automatically do your encoding and decoding.  In this way its very simple to build
higher level APIs:

```elixir
defmodule XMLRPC do
  use HTTPoison.Base

  def process_request_body(body), do: XMLRPC.encode(body)
  def process_response_body(body), do: XMLRPC.decode(body)
end

iex> request = %XMLRPC.MethodCall{method_name: "test.sumprod", params: [2,3]}
iex> response = HTTPoison.post!("http://www.advogato.org/XMLRPC", request).body
{:ok, %XMLRPC.MethodResponse{param: [5, 6]}}
```

HTTPoison allows you to hook into other parts of the request process and handle
authentication, URL schemes and easily build out a complete API module.

### Server

Using say Phoenix, you can handle an incoming request and decode as above.
XMLRPC implements the `encode_to_iodata!` call, which allows pluggable response
handlers to automatically encode your response

## Copyright and License

Copyright (c) 2015 Ed Wildgoose

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [https://www.apache.org/licenses/LICENSE-2.0](https://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
