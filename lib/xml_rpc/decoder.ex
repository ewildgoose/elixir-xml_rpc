defmodule XMLRPC.Decoder do

  @xmlrpc_xsd """
<?xml version="1.0"?>
<xsd:schema xmlns:xsd="http://www.w3.org/2001/XMLSchema">

 <xsd:element name="methodCall">
    <xsd:complexType>
      <xsd:all>
        <xsd:element name="methodName">
          <xsd:simpleType>
            <xsd:restriction base="ASCIIString">
              <xsd:pattern value="([A-Za-z0-9]|/|\.|:|_)*" />
            </xsd:restriction>
          </xsd:simpleType>
        </xsd:element>
        <xsd:element name="params" minOccurs="0" maxOccurs="1">
          <xsd:complexType>
            <xsd:sequence>
              <xsd:element name="param"  type="ParamType"
                           minOccurs="0" maxOccurs="unbounded" />
            </xsd:sequence>
          </xsd:complexType>
         </xsd:element>
      </xsd:all>
    </xsd:complexType>
  </xsd:element>

  <xsd:element name="methodResponse">
    <xsd:complexType>
      <xsd:choice>
        <xsd:element name="params">
          <xsd:complexType>
            <xsd:sequence>
              <xsd:element name="param" type="ParamType" />
            </xsd:sequence>
          </xsd:complexType>
        </xsd:element>
        <xsd:element name="fault">
          <xsd:complexType>
            <xsd:sequence>
              <xsd:element name="value">
                <xsd:complexType>
                  <xsd:sequence>
                    <xsd:element name="struct">
                      <xsd:complexType>
                        <xsd:sequence>
                          <xsd:element name="member" type="MemberType"
                                       minOccurs="2" maxOccurs="2" />
                        </xsd:sequence>
                      </xsd:complexType>
                    </xsd:element>
                  </xsd:sequence>
                </xsd:complexType>
              </xsd:element>
            </xsd:sequence>
          </xsd:complexType>
         </xsd:element>
      </xsd:choice>
    </xsd:complexType>
  </xsd:element>

  <xsd:complexType name="ParamType">
    <xsd:sequence>
      <xsd:element name="value" type="ValueType" />
    </xsd:sequence>
  </xsd:complexType>

  <xsd:complexType name="ValueType" mixed="true">
    <xsd:choice>
      <xsd:element name="i4"            type="xsd:int" />
      <xsd:element name="int"           type="xsd:int" />
      <xsd:element name="string"        type="ASCIIString" />
      <xsd:element name="double"        type="xsd:decimal" />
      <xsd:element name="Base64"        type="xsd:base64Binary" />
      <xsd:element name="boolean"       type="NumericBoolean" />
      <xsd:element name="dateTime.iso8601" type="xsd:dateTime" />
      <xsd:element name="array"         type="ArrayType" />
      <xsd:element name="struct"        type="StructType" />
      <xsd:element name="nil"           type="NilType" />
    </xsd:choice>
  </xsd:complexType>

  <xsd:complexType name="StructType">
    <xsd:sequence>
      <xsd:element name="member" type="MemberType"
                   maxOccurs="unbounded" />
    </xsd:sequence>
  </xsd:complexType>

  <xsd:complexType name="MemberType">
    <xsd:sequence>
      <xsd:element name="name"  type="xsd:string" />
      <xsd:element name="value" type="ValueType" />
    </xsd:sequence>
  </xsd:complexType>

  <xsd:complexType name="ArrayType">
    <xsd:sequence>
      <xsd:element name="data">
        <xsd:complexType>
          <xsd:sequence>
            <xsd:element name="value"  type="ValueType"
                         minOccurs="0" maxOccurs="unbounded" />
          </xsd:sequence>
        </xsd:complexType>
      </xsd:element>
    </xsd:sequence>
  </xsd:complexType>

  <xsd:simpleType name="ASCIIString">
    <xsd:restriction base="xsd:string">
      <xsd:pattern value="([ -~]|\n|\r|\t)*" />
    </xsd:restriction>
  </xsd:simpleType>

  <xsd:simpleType name="NumericBoolean">
    <xsd:restriction base="xsd:boolean">
      <xsd:pattern value="0|1" />
    </xsd:restriction>
  </xsd:simpleType>

  <xsd:complexType name="NilType">
  </xsd:complexType>

</xsd:schema>
"""


  @doc """
  Decode an XML-RPC Call or Response object

  It returns `{:ok, decoded}` on success
  {:error, reason} on any parse failure

  The decoded result will be either a XMLRPC.MethodCall, XMLRPC.MethodResponse
  or XMLRPC.Fault struct.
  """
  def decode(xml) do
    {:ok, model} = :erlsom.compile_xsd(@xmlrpc_xsd)

    case :erlsom.scan(xml, model, [{:output_encoding, :utf8}]) do
      {:error, [{:exception, {_error_type, {error}}}, _stack, _received]} when is_list(error) ->
                              {:error, List.to_string(error)}
      {:error, [{:exception, {_error_type, error}}, _stack, _received]} ->
                              {:error, error}
      {:error, message} when is_list(message) ->
                              {:error, List.to_string(message)}
      {:ok, struct, _rest} -> {:ok, parse(struct)}
    end

  end

  # ##########################################################################
  # Top level parsers.
  # Pickup the main type of the thing being parsed and setup appropriate result objects

  # Parse a method 'Call'
  defp parse(  {:methodCall, [], method_name,
                {:"methodCall/params", [], params }} )
      when is_list(params)
  do
    %XMLRPC.MethodCall{ method_name: method_name, params: parse_params(params) }
  end

  # Parse a 'fault' Response
  defp parse(  {:methodResponse, [],
                {:"methodResponse/fault", [],
                  {:"methodResponse/fault/value", [],
                    {:"methodResponse/fault/value/struct", [], fault_struct} }}} )
      when is_list(fault_struct)
  do
    fault = parse_struct(fault_struct)
    fault_code = Dict.get(fault, "faultCode")
    fault_string = Dict.get(fault, "faultString")
    %XMLRPC.Fault{ fault_code: fault_code, fault_string: fault_string }
  end

  # Parse any other 'Response'
  defp parse(  {:methodResponse, [],
                {:"methodResponse/params", [], param}} )
      when is_tuple(param)
  do
    %XMLRPC.MethodResponse{ param: parse_param(param) }
  end

  # ##########################################################################

  # Parse an 'array' atom
  defp parse_atom( {:ValueType, [], [{:ArrayType, [], {:"ArrayType/data", [], array}}]} )
      when is_list(array)
  do
    parse_array(array)
  end

  # Parse a 'struct' atom
  defp parse_atom( {:ValueType, [], [{:StructType, [],                   struct}]} )
      when is_list(struct)
  do
    parse_struct(struct)
  end

  # Parse an 'integer' atom
  defp parse_atom( {:ValueType, [], [{:"ValueType-int", [],              int}]} )
      when is_integer(int)
  do
      int
  end

  # Parse a 'float' atom
  defp parse_atom( {:ValueType, [], [{:"ValueType-double", [],           float}]} ) do
    Float.parse(float)
    |> elem(0)
  end

  # Parse a 'boolean' atom
  defp parse_atom( {:ValueType, [], [{:"ValueType-boolean", [],          boolean}]} ) do
    case boolean do
      "0" -> false
      "1" -> true
    end
  end

  # Parse a 'datetime' atom (needs decoding from bolloxed iso8601 alike format...)
  defp parse_atom( {:ValueType, [], [{:"ValueType-dateTime.iso8601", [], datetime}]} ) do
    %XMLRPC.DateTime{raw: datetime}
  end

  # Parse a 'string' atom
  defp parse_atom( {:ValueType, [], [{:"ValueType-string", [],           string}]} ) do
    string
  end

  # Parse a 'nil' atom
  # Note: this is an xml-rpc extension
  defp parse_atom( {:ValueType, [], [NilType: []]} ) do
    nil
  end

  # ##########################################################################

  # Parse the 'struct'
  # 'structs' are a list of key-value pairs
  # Note: values can be 'structs'/'arrays' as well as other atom types
  defp parse_struct(doc) when is_list(doc) do
    doc
    |> Enum.reduce  Map.new,
                    fn(member, acc) ->
                        parse_member(member)
                        |> Enum.into acc
                    end
  end

  # Parse the 'array'
  # 'arrays' are just an ordered list of other atom values
  # Note: values can be 'structs'/'arrays' as well as other atom types
  defp parse_array(doc) when is_list(doc) do
    doc
    |> Enum.map &parse_atom/1
  end

  # ##########################################################################

  # Parse a list of Parameter values (implies a Request)
  defp parse_params( values ) when is_list(values) do
    values
    |> Enum.map &parse_param/1
  end

  # Parse a single Parameter
  defp parse_param( {:ParamType, [], value } ), do: parse_atom(value)

  # ##########################################################################

  # Parse one member of a Struct
  defp parse_member( {:MemberType, [], name, value } ) do
    [{name, parse_atom(value)}]
  end





  def escape_string(string) do
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
    |> String.replace("\x0d", "&#xd;")
  end

end
