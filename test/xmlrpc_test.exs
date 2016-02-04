defmodule XMLRPC.DecoderTest do
  use ExUnit.Case, async: true
  doctest XMLRPC
  doctest XMLRPC.DateTime
  doctest XMLRPC.Base64

  @rpc_simple_call_1 """
<?xml version="1.0" encoding="UTF-8"?>
<methodCall>
   <methodName>sample.sum</methodName>
   <params>
      <param>
         <value><int>17</int></value>
      </param>

      <param>
         <value><int>13</int></value>
      </param>
   </params>
</methodCall>
"""

  @rpc_simple_call_1_elixir %XMLRPC.MethodCall{method_name: "sample.sum", params: [17, 13]}


  @rpc_simple_response_1 """
<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
   <params>
      <param>
         <value><int>30</int></value>
      </param>
   </params>
</methodResponse>
"""

  @rpc_simple_response_1_elixir %XMLRPC.MethodResponse{param: 30}


  @rpc_fault_1 """
<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
  <fault>
    <value>
      <struct>
        <member>
          <name>faultCode</name>
          <value><int>4</int></value>
        </member>
        <member>
          <name>faultString</name>
          <value><string>Too many parameters.</string></value>
        </member>
      </struct>
    </value>
  </fault>
</methodResponse>
"""

  @rpc_fault_1_elixir            %XMLRPC.Fault{fault_code: 4, fault_string: "Too many parameters."}


  @rpc_response_all_array """
<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
  <params>
    <param>
      <value>
        <array>
          <data>
            <value><int>30</int></value>
            <value><boolean>1</boolean></value>
            <value><dateTime.iso8601>19980717T14:08:55</dateTime.iso8601></value>
            <value><double>-12.53</double></value>
            <value><string>Something here</string></value>
            <value><nil/></value>
          </data>
        </array>
      </value>
    </param>
  </params>
</methodResponse>
"""
  @rpc_response_all_array_elixir %XMLRPC.MethodResponse{param:
                                  [30, true,
                                    %XMLRPC.DateTime{raw: "19980717T14:08:55"},
                                    -12.53, "Something here", nil]}


  @rpc_response_all_struct """
<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
  <params>
    <param>
      <value>
        <struct>
          <member>
            <name>bool</name>
            <value><boolean>1</boolean></value>
          </member>
          <member>
            <name>datetime</name>
            <value><dateTime.iso8601>19980717T14:08:55</dateTime.iso8601></value>
          </member>
          <member>
            <name>double</name>
            <value><double>-12.53</double></value>
          </member>
          <member>
            <name>int</name>
            <value><int>30</int></value>
          </member>
          <member>
            <name>nil</name>
            <value><nil/></value>
          </member>
          <member>
            <name>string</name>
            <value><string>Something here</string></value>
          </member>
        </struct>
      </value>
    </param>
  </params>
</methodResponse>
"""

  @rpc_response_all_struct_elixir %XMLRPC.MethodResponse{param:
                                  %{"bool" => true,
                                    "datetime" => %XMLRPC.DateTime{raw: "19980717T14:08:55"},
                                    "double" => -12.53, "int" => 30, "nil" => nil,
                                    "string" => "Something here"}}


  @rpc_response_nested """
<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
  <params>
    <param>
      <value>

        <array>
          <data>
            <value><int>30</int></value>
            <value><nil/></value>

            <value>
              <struct>
                <member>
                  <name>array</name>
                  <value>

                    <array>
                      <data>
                        <value><int>30</int></value>
                      </data>
                    </array>

                  </value>
                </member>
              </struct>
            </value>
          </data>

        </array>

      </value>
    </param>
  </params>
</methodResponse>
"""

  @rpc_response_nested_elixir     %XMLRPC.MethodResponse{param:
                                    [30, nil, %{"array" => [30]} ]}


  @rpc_response_empty_array """
<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
  <params>
    <param>
      <value>
        <array>
          <data></data>
        </array>
      </value>
    </param>
  </params>
</methodResponse>
"""

  @rpc_response_empty_array_elixir %XMLRPC.MethodResponse{param: []}


  @rpc_response_optional_string_tag """
<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
  <params>
    <param>
      <value>a4sdfff7dad8</value>
    </param>
  </params>
</methodResponse>
"""

  @rpc_response_optional_string_tag_elixir %XMLRPC.MethodResponse{param: "a4sdfff7dad8"}

  @rpc_response_empty_string_tag """
<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
  <params>
    <param>
      <value><string></string></value>
    </param>
  </params>
</methodResponse>
"""

  @rpc_response_empty_string_tag_elixir %XMLRPC.MethodResponse{param: ""}

  @rpc_response_optional_empty_string_tag """
<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
  <params>
    <param>
      <value></value>
    </param>
  </params>
</methodResponse>
"""

  @rpc_response_optional_empty_string_tag_elixir %XMLRPC.MethodResponse{param: ""}


  @rpc_response_invalid_1 """
<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
  <params>
    <param>
      <value><int>30</int></value>
    </param>

    <param>
      <value><int>30</int></value>
    </param>
   </params>
</methodResponse>
"""

  @rpc_response_invalid_2 """
<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
  <params>
    <param>
      <value><int>30</int></value>
    </param2>
 </params>
</methodResponse>
"""

  @rpc_response_invalid_3_elixir %XMLRPC.MethodResponse{param: HashSet.new}


  # ##########################################################################


  test "decode rpc_simple_call_1" do
    decode = XMLRPC.decode(@rpc_simple_call_1)
    assert decode == {:ok, @rpc_simple_call_1_elixir}
  end

  test "decode rpc_simple_response_1" do
    decode = XMLRPC.decode!(@rpc_simple_response_1)
    assert decode == @rpc_simple_response_1_elixir
  end

  test "decode rpc_fault_1" do
    decode = XMLRPC.decode(@rpc_fault_1)
    assert decode == {:ok, @rpc_fault_1_elixir}
  end

  test "decode rpc_response_all_array" do
    decode = XMLRPC.decode(@rpc_response_all_array)
    assert decode == {:ok, @rpc_response_all_array_elixir}
  end

  test "decode rpc_response_all_struct" do
    decode = XMLRPC.decode(@rpc_response_all_struct)
    assert decode == {:ok, @rpc_response_all_struct_elixir}
  end

  test "decode rpc_response_nested" do
    decode = XMLRPC.decode(@rpc_response_nested)
    assert decode == {:ok, @rpc_response_nested_elixir}
  end

  test "decode rpc_response_empty_array" do
    decode = XMLRPC.decode(@rpc_response_empty_array)
    assert decode == {:ok, @rpc_response_empty_array_elixir}
  end

  test "decode rpc_response_optional_string_tag" do
    decode = XMLRPC.decode(@rpc_response_optional_string_tag)
    assert decode == {:ok, @rpc_response_optional_string_tag_elixir}
  end

  test "decode rpc_response_empty_string_tag" do
    decode = XMLRPC.decode(@rpc_response_empty_string_tag)
    assert decode == {:ok, @rpc_response_empty_string_tag_elixir}
  end

  test "decode rpc_response_optional_empty_string_tag" do
    decode = XMLRPC.decode(@rpc_response_optional_empty_string_tag)
    assert decode == {:ok, @rpc_response_optional_empty_string_tag_elixir}
  end

  test "decode rpc_response_invalid_1" do
    decode = XMLRPC.decode(@rpc_response_invalid_1)
    assert decode == {:error, "1 - Unexpected event, expected end-tag"}
  end

  test "decode rpc_response_invalid_2" do
    decode = XMLRPC.decode(@rpc_response_invalid_2)
    assert decode == {:error, "Malformed: Tags don\'t match"}
  end

  # ##########################################################################


  test "encode rpc_simple_call_1" do
    encode = XMLRPC.encode!(@rpc_simple_call_1_elixir)
             |> IO.iodata_to_binary

    assert encode == strip_space(@rpc_simple_call_1)
  end

  test "encode rpc_simple_response_1" do
    encode = XMLRPC.encode!(@rpc_simple_response_1_elixir)
             |> IO.iodata_to_binary

    assert encode == strip_space(@rpc_simple_response_1)
  end

  test "encode rpc_fault_1" do
    encode = XMLRPC.encode!(@rpc_fault_1_elixir)
             |> IO.iodata_to_binary

    assert encode == strip_space(@rpc_fault_1)
  end

  test "encode rpc_response_all_array" do
    encode = XMLRPC.encode!(@rpc_response_all_array_elixir)
             |> IO.iodata_to_binary

    assert encode == strip_space(@rpc_response_all_array)
  end

  test "encode rpc_response_all_struct" do
    encode = XMLRPC.encode!(@rpc_response_all_struct_elixir)
             |> IO.iodata_to_binary

    assert encode == strip_space(@rpc_response_all_struct)
  end

  test "encode rpc_response_nested" do
    encode = XMLRPC.encode!(@rpc_response_nested_elixir)

    assert encode == strip_space(@rpc_response_nested)
  end

  test "encode rpc_response_empty_array" do
    encode = XMLRPC.encode!(@rpc_response_empty_array_elixir)

    assert encode == strip_space(@rpc_response_empty_array)
  end

  test "encode rpc_response_invalid_3" do
    assert_raise XMLRPC.EncodeError, fn ->
      XMLRPC.encode!(@rpc_response_invalid_3_elixir)
    end
  end

  # ##########################################################################


  # Helper functions
  #
  defp strip_space(string) do
    Regex.replace(~r/>\s+</, string, "><")
    |> String.strip
  end


end
