defmodule XMLRPC.EncodeError do
  defexception value: nil, message: nil
end


defmodule XMLRPC.Encode do
  @moduledoc """
  Utility functions helpful for encoding XML.
  """

  @doc """
  Wrap a value in an XML tag.

  Note: For xml-rpc we need only a very minimal XML generator.
  """
  def tag(tag, value) do
    ["<#{tag}>", value, "</#{tag}>"]
  end

  @doc """
  Escape special characters in XML attributes.

  Note: technically you only need to escape "&" and "<" in tags, however,
  its common to also escape ">".  For attributes you must additionally escape
  both single and double quotes, but its convenient to also escape \r and \n
  """
  def escape_attr(string) do
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
    |> String.replace("\x0d", "&#xd;")
    |> String.replace("\x0a", "&#xa;")
  end
end


defmodule XMLRPC.Encoder do
  @moduledoc """
  This module does the work of encoding an XML-RPC call or response.
  """

  import XMLRPC.Encode, only: [tag: 2]

  def encode!(%XMLRPC.MethodCall{method_name: method_name, params: params}, options) do
    ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"] ++
    tag("methodCall",
      tag("methodName",
        method_name) ++
      tag("params",
        encode_params(params, options)))
  end

  def encode!(%XMLRPC.MethodResponse{ param: param }, options) do
    ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"] ++
      tag("methodResponse",
        tag("params",
          encode_param(param, options)))
  end

  def encode!(%XMLRPC.Fault{ fault_code: fault_code, fault_string: fault_string }, options) do
    fault = %{faultCode: fault_code, faultString: fault_string}

    ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"] ++
    tag("methodResponse",
      tag("fault",
        encode_value(fault, options)))
  end

  # ##########################################################################

  defp encode_params(params, options) do
    Enum.map params, fn p -> encode_param(p, options) end
  end

  defp encode_param(param, options) do
    tag "param", encode_value(param, options)
  end

  # ##########################################################################

  def encode_value(value, options) do
    tag("value", XMLRPC.ValueEncoder.encode(value, options))
  end

end


  # ##########################################################################

defprotocol XMLRPC.ValueEncoder do
  @fallback_to_any true

  def encode(value, options)
end


defimpl XMLRPC.ValueEncoder, for: Atom do
  import XMLRPC.Encode, only: [tag: 2, escape_attr: 1]

  # encode nil value (default to enabled)
  def encode(nil, options) do
    if options[:exclude_nil] do
      raise XMLRPC.EncodeError, value: nil, message: "unable to encode value: nil"
    else
      ["<nil/>"]
    end
  end

  def encode(true, _options),  do: tag("boolean", "1")
  def encode(false, _options), do: tag("boolean", "0")

  def encode(atom, _options), do: tag("string",
                                      atom
                                      |> Atom.to_string
                                      |> escape_attr )
end


defimpl XMLRPC.ValueEncoder, for: BitString do
  import XMLRPC.Encode, only: [tag: 2, escape_attr: 1]

  def encode(string, _options) do
    tag("string",
        escape_attr(string))
  end
end


defimpl XMLRPC.ValueEncoder, for: Integer do
  import XMLRPC.Encode, only: [tag: 2]

  def encode(int, _options), do: tag("int", Integer.to_string(int))
end


defimpl XMLRPC.ValueEncoder, for: Float do
  import XMLRPC.Encode, only: [tag: 2]

  def encode(double, _options) do
    # Something of a format hack in the absence of a proper pretty printer
    # On average will round trip a float back to the original simple string
    tag("double", Float.to_string(double))
  end
end

defimpl XMLRPC.ValueEncoder, for: Decimal do
  import XMLRPC.Encode, only: [tag: 2]

  def encode(double, _options) do
    # Something of a format hack in the absence of a proper pretty printer
    # On average will round trip a float back to the original simple string
    tag("double", double |> Decimal.reduce() |> Decimal.to_string())
  end
end


defimpl XMLRPC.ValueEncoder, for: XMLRPC.DateTime do
  import XMLRPC.Encode, only: [tag: 2]

  def encode(%XMLRPC.DateTime{raw: datetime}, _options) do
    tag("dateTime.iso8601", datetime)
  end
end


defimpl XMLRPC.ValueEncoder, for: XMLRPC.Base64 do
  import XMLRPC.Encode, only: [tag: 2]

  def encode(%XMLRPC.Base64{raw: base64}, _options) do
      tag("base64", base64)
  end
end


defimpl XMLRPC.ValueEncoder, for: List do
  import XMLRPC.Encode, only: [tag: 2]

  def encode(array, options) do
      tag("array",
        tag("data",
          array |> Enum.map(fn v -> XMLRPC.Encoder.encode_value(v, options) end) ) )
  end
end

defimpl XMLRPC.ValueEncoder, for: Map do
  import XMLRPC.Encode, only: [tag: 2, escape_attr: 1]

  # Parse a general map structure.
  # Note: This will also match structs, so define those above this definition
  def encode(struct, options) do
      tag("struct",
        struct |> Enum.map(fn m -> encode_member(m, options) end))
  end

  # Individual items of a struct. Basically key/value pair
  def encode_member({key, value}, options) when is_atom(key) do
    encode_member({Atom.to_string(key), value}, options)
  end

  def encode_member({key, value}, options) when is_bitstring(key) do
    tag("member",
      tag("name", escape_attr(key)) ++
      XMLRPC.Encoder.encode_value(value, options) )
  end
end

defimpl XMLRPC.ValueEncoder, for: Any do
  def encode(%{__struct__: _} = struct, options) do
    XMLRPC.ValueEncoder.Map.encode(Map.from_struct(struct), options)
  end

  def encode(value, _options) do
    raise XMLRPC.EncodeError,
          value: value,
          message: "unable to encode value: #{inspect value}"
  end
end

  # defp encode_value(_) do
  #   throw({:error, "Unknown value type"})
  # end
