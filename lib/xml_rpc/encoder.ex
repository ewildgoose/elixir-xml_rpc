defmodule XMLRPC.Encoder do

  def encode(fault = %XMLRPC.Fault{}) do
    encode_fault(fault) |> IO.iodata_to_binary
  end

  def encode(call = %XMLRPC.MethodCall{}) do
    encode_call(call) |> IO.iodata_to_binary
  end

  def encode(response = %XMLRPC.MethodResponse{}) do
    encode_response(response) |> IO.iodata_to_binary
  end

  # Create a simple XML tag
  def tag(tag, value) do
    ["<#{tag}>", value, "</#{tag}>"]
  end

  # ##########################################################################

  defp encode_call(%XMLRPC.MethodCall{method_name: method_name, params: params}) do
    ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"]
    ++ tag "methodCall",
        tag("methodName",
            method_name)
        ++ tag "params",
            encode_params(params)
  end

  defp encode_response(%XMLRPC.MethodResponse{ param: param }) do
    ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"]
    ++ tag("methodResponse",
        tag("params",
            encode_param(param)))
  end

  defp encode_fault(%XMLRPC.Fault{ fault_code: fault_code, fault_string: fault_string }) do
    fault = %{faultCode: fault_code, faultString: fault_string}

    ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>"]
    ++ tag("methodResponse",
        tag("fault",
            encode_value(fault)))
  end

  # ##########################################################################

  defp encode_params(params) do
    Enum.map params, &encode_param/1
  end

  defp encode_param(param) do
    tag "param", encode_value(param)
  end

  # Individual items of a struct. Basically key/value pair
  defp encode_member({key, value}) when is_atom(key) do
    encode_member({Atom.to_string(key), value})
  end

  defp encode_member({key, value}) when is_bitstring(key) do
    tag("member",
      tag("name", key)
      ++ encode_value(value))
  end

  # ##########################################################################


  defp encode_value(int) when is_integer(int) do
    tag("value",
      tag("int",
        Integer.to_string(int)))
  end

  defp encode_value(double) when is_float(double) do
    tag("value",
      tag("double",
        Float.to_string(double, [decimals: 14, compact: true])))
  end

  defp encode_value(true) do
    tag("value",
      tag("boolean", "1"))
  end

  defp encode_value(false) do
    tag("value",
      tag("boolean", "0"))
  end

  defp encode_value(nil) do
    tag("value",
      "<nil/>")
  end

  defp encode_value(%XMLRPC.DateTime{raw: datetime}) do
    tag("value",
      tag("dateTime.iso8601", datetime))
  end

  defp encode_value(%XMLRPC.Base64{raw: base64}) do
    tag("value",
      tag("base64", base64))
  end

  defp encode_value(string) when is_bitstring(string) do
    tag("value",
      tag("string", string))
  end

  defp encode_value(array) when is_list(array) do
    tag("value",
      tag("array",
        tag("data",
          array |> Enum.map &encode_value/1 ) ) )
  end

  # Parse a general map structure.
  # Note: This will also match structs, so define those above this definition
  defp encode_value(struct) when is_map(struct) do
    tag("value",
      tag("struct",
        struct |> Enum.map &encode_member/1))
  end


  defp encode_value(_) do
    throw({:error, "Unknown value type"})
  end


end