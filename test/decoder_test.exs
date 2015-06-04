defmodule XMLRPC.DecoderTest do
  use ExUnit.Case

@rpc_simple_call_1 """
<?xml version="1.0" encoding="ISO-8859-1"?>
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

@rpc_simple_response_1 """
<?xml version="1.0" encoding="ISO-8859-1"?>
<methodResponse>
   <params>
      <param>
         <value><int>30</int></value>
      </param>
   </params>
</methodResponse>
"""

@rpc_fault_1 """
<?xml version="1.0"?>
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

@rpc_response_invalid_1 """
<?xml version='1.0'?>
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
<?xml version='1.0'?>
<methodResponse>
    <params>
        <param>
            <value><int>30</int></value>
        </param2>
   </params>
</methodResponse>
"""

@rpc_response_all_array """
<?xml version='1.0'?>
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

@rpc_response_all_struct """
<?xml version='1.0'?>
<methodResponse>
    <params>
        <param>
            <value>
                <struct>
                    <member>
                        <name>int</name>
                        <value><int>30</int></value>
                    </member>
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
                        <name>string</name>
                        <value><string>Something here</string></value>
                    </member>
                    <member>
                        <name>nil</name>
                        <value><nil/></value>
                    </member>
                </struct>
            </value>
        </param>
    </params>
</methodResponse>
"""

@rpc_response_nested """
<?xml version='1.0'?>
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



  test "decode rpc_simple_call_1" do
    decode = XMLRPC.Decoder.decode(@rpc_simple_call_1)
    assert decode == {:ok, %XMLRPC.MethodCall{method_name: "sample.sum", parameters: [17, 13]}}
  end

  test "decode rpc_simple_response_1" do
    decode = XMLRPC.Decoder.decode(@rpc_simple_response_1)
    assert decode == {:ok, %XMLRPC.MethodResponse{parameter: 30}}
  end

  test "decode rpc_fault_1" do
    decode = XMLRPC.Decoder.decode(@rpc_fault_1)
    assert decode == {:ok,
                      %XMLRPC.Fault{fault_code: 4, fault_string: "Too many parameters."}}
  end

  test "decode rpc_response_invalid_1" do
    decode = XMLRPC.Decoder.decode(@rpc_response_invalid_1)
    assert decode == {:error, "1 - Unexpected event, expected end-tag"}
  end

  test "decode rpc_response_invalid_2" do
    decode = XMLRPC.Decoder.decode(@rpc_response_invalid_2)
    assert decode == {:error, "Malformed: Tags don\'t match"}
  end

  test "decode rpc_response_all_array" do
    decode = XMLRPC.Decoder.decode(@rpc_response_all_array)
    assert decode == {:ok,
                       %XMLRPC.MethodResponse{parameter: [30, true,
                         %XMLRPC.DateTime{raw: "19980717T14:08:55"}, -12.53, "Something here", nil]}}
  end

  test "decode rpc_response_all_struct" do
    decode = XMLRPC.Decoder.decode(@rpc_response_all_struct)
    assert decode == {:ok,
                      %XMLRPC.MethodResponse{parameter: %{"bool" => true,
                          "datetime" => %XMLRPC.DateTime{raw: "19980717T14:08:55"},
                          "double" => -12.53, "int" => 30, "nil" => nil,
                          "string" => "Something here"}}}
  end



end
