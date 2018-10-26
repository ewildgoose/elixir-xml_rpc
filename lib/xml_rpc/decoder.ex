defmodule XMLRPC.DecodeError do
  defexception message: nil
end

defmodule XMLRPC.Decoder do

  alias XMLRPC.DecodeError
  alias XMLRPC.Fault
  alias XMLRPC.MethodCall
  alias XMLRPC.MethodResponse

  # Load our XML Schema from an external file
  @xmlrpc_xsd_file Path.join(__DIR__, "xmlrpc.xsd")
  @external_resource @xmlrpc_xsd_file
  @xmlrpc_xsd File.read!(@xmlrpc_xsd_file)

  @moduledoc """
  This module does the work of decoding an XML-RPC call or response.
  """

  @doc """
  Decode an XML-RPC Call or Response object

  Input:
  iodata consisting of the input XML string
  options:
    exclude_nil: false (default) - allow decoding of <nil/> values

  Output:
  On any parse failure raises XMLRPC.DecodeError

  On success the decoded result will be a struct, either:
  * XMLRPC.MethodCall
  * XMLRPC.MethodResponse
  * XMLRPC.Fault
  """
  def decode!(iodata, options) do
    {:ok, model} = :erlsom.compile_xsd(@xmlrpc_xsd)
    xml = IO.iodata_to_binary(iodata)

    case :erlsom.scan(xml, model, [{:output_encoding, :utf8}]) do
      {:error, [{:exception, {_error_type, {error}}}, _stack, _received]} when is_list(error) ->
          raise DecodeError, message: List.to_string(error)
      {:error, [{:exception, {_error_type, error}}, _stack, _received]} ->
          raise DecodeError, message: error
      {:error, message} when is_list(message) ->
          raise DecodeError, message: List.to_string(message)
      {:ok, struct, _rest} ->
          parse(struct, options)
    end

  end

  # ##########################################################################
  # Top level parsers.
  # Pickup the main type of the thing being parsed and setup appropriate result objects

  # Parse a method 'Call'
  defp parse(  {:methodCall, [], method_name,
                {:"methodCall/params", [], params }},
               options )
      when is_list(params)
  do
    %MethodCall{ method_name: method_name, params: parse_params(params, options) }
  end

  # Parse a method 'Call' with no (:undefined) params
  defp parse(  {:methodCall, [], method_name,
                {:"methodCall/params", [], :undefined }},
               options )
  do
    %MethodCall{ method_name: method_name, params: parse_params([], options) }
  end

  # Parse a method 'Call' with completely missing params array
  defp parse(  {:methodCall, [], method_name,
                :undefined},
               options )
  do
    %MethodCall{ method_name: method_name, params: parse_params([], options) }
  end

  # Parse a 'fault' Response
  defp parse(  {:methodResponse, [],
                {:"methodResponse/fault", [],
                  {:"methodResponse/fault/value", [],
                    {:"methodResponse/fault/value/struct", [], fault_struct} }}},
                options )
      when is_list(fault_struct)
  do
    fault = parse_struct(fault_struct, options)
    fault_code = Map.get(fault, "faultCode")
    fault_string = Map.get(fault, "faultString")
    %Fault{ fault_code: fault_code, fault_string: fault_string }
  end

  # Parse any other 'Response'
  defp parse(  {:methodResponse, [],
                {:"methodResponse/params", [], param}},
               options )
      when is_tuple(param)
  do
    %MethodResponse{ param: parse_param(param, options) }
  end

  # ##########################################################################

  # Parse an 'array' atom
  defp parse_value( {:ValueType, [], [{:ArrayType, [], {:"ArrayType/data", [], array}}]}, options ) do
    parse_array(array, options)
  end

  # Parse a 'struct' atom
  defp parse_value( {:ValueType, [], [{:StructType, [],                   struct}]}, options)
      when is_list(struct)
  do
    parse_struct(struct, options)
  end

  defp parse_value( {:ValueType, [], [{:StructType, [], _struct}]}, _options) do
    %{}
  end

  # Parse an 'integer' atom
  defp parse_value( {:ValueType, [], [{:"ValueType-int", [],              int}]}, _options)
      when is_integer(int)
  do
      int
  end

  # Parse an 'i4' atom (32 bit integer)
  defp parse_value( {:ValueType, [], [{:"ValueType-i4", [],              int}]}, _options)
      when is_integer(int)
  do
      int
  end

  # Parse an 'i8' atom (64 bit integer)
  defp parse_value( {:ValueType, [], [{:"ValueType-i8", [],              int}]}, _options)
      when is_integer(int)
  do
      int
  end

  # Parse a 'float' atom
  defp parse_value( {:ValueType, [], [{:"ValueType-double", [],           float}]}, _options) do
    Float.parse(float)
    |> elem(0)
  end

  # Parse a 'boolean' atom
  defp parse_value( {:ValueType, [], [{:"ValueType-boolean", [],          boolean}]}, _options) do
    case boolean do
      "0" -> false
      "1" -> true
    end
  end

  # Parse a 'datetime' atom (needs decoding from bolloxed iso8601 alike format...)
  defp parse_value( {:ValueType, [], [{:"ValueType-dateTime.iso8601", [], datetime}]}, _options) do
    %XMLRPC.DateTime{raw: datetime}
  end

  # Parse a 'base64' atom
  defp parse_value( {:ValueType, [], [{:"ValueType-base64", [],           string}]}, _options) do
    %XMLRPC.Base64{raw: string}
  end

  # Parse an empty 'string' atom
  defp parse_value( {:ValueType, [], [{:"ValueType-string", [],           []}]}, _options) do
    ""
  end

  # Parse a 'string' atom
  defp parse_value( {:ValueType, [], [{:"ValueType-string", [],           string}]}, _options) do
    string
  end

  # A string value can optionally drop the type specifier. The node is assumed to be a string value
  defp parse_value( {:ValueType, [], [string]                                     }, _options) when is_binary(string) do
    string
  end

  # An empty string that drops the type specifier will parse as :undefined instead of an empty binary.
  defp parse_value( {:ValueType, [], :undefined                                   }, _options) do
    ""
  end

  # Parse a 'nil' atom
  # Note: this is an xml-rpc extension
  defp parse_value( {:ValueType, [], [NilType: []]}, options) do
    if options[:exclude_nil] do
      raise XMLRPC.DecodeError, message: "unable to decode <nil/>"
    else
      nil
    end
  end

  # ##########################################################################

  # Parse the 'struct'
  # 'structs' are a list of key-value pairs
  # Note: values can be 'structs'/'arrays' as well as other atom types
  defp parse_struct(doc, options) when is_list(doc) do
    doc
    |> Enum.reduce(Map.new,
                        fn(member, acc) ->
                            parse_member(member, options)
                            |> Enum.into(acc)
                        end)
  end

  # Parse the 'array'
  # 'arrays' are just an ordered list of other atom values
  # Note: values can be 'structs'/'arrays' as well as other atom types
  defp parse_array(doc, options) when is_list(doc) do
    doc
    |> Enum.map(fn v -> parse_value(v, options) end)
  end

  # Empty array, ie <array><data/></data>
  defp parse_array(:undefined, _options), do: []

  # ##########################################################################

  # Parse a list of Parameter values (implies a Request)
  defp parse_params(values, options) when is_list(values) do
    values
    |> Enum.map(fn p -> parse_param(p, options) end)
  end

  # Parse a single Parameter
  defp parse_param( {:ParamType, [], value }, options ), do: parse_value(value, options)

  # ##########################################################################

  # Parse one member of a Struct
  defp parse_member( {:MemberType, [], name, value }, options ) do
    [{name, parse_value(value, options)}]
  end

end
