defmodule XMLRPC.Tesla.MiddlewareTest do
  use ExUnit.Case

  describe "basic" do
    defmodule Client do
      use Tesla

      plug(XMLRPC.Tesla.Middleware)

      adapter(fn env ->
        {status, headers, body} =
          case env.url do
            "/decode" ->
              {200, [{"content-type", "application/xml"}], ~s(
                <?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
   <params>
      <param>
         <value><int>30</int></value>
      </param>
   </params>
</methodResponse>)}

            "/encode" ->
              {200, [{"content-type", "application/xml"}],
               env.body |> String.replace("foo", "baz")}

            "/empty" ->
              {200, [{"content-type", "application/xml"}], nil}

            "/empty-string" ->
              {200, [{"content-type", "application/xml"}], ""}

            "/invalid-content-type" ->
              {200, [{"content-type", "text/plain"}], "hello"}

            "/invalid-xml-format" ->
              {200, [{"content-type", "application/xml"}], "{\"foo\": bar}"}

            "/invalid-xml-encoding" ->
              {200, [{"content-type", "application/xml"}],
               <<123, 34, 102, 111, 111, 34, 58, 32, 34, 98, 225, 114, 34, 125>>}

            "/raw" ->
              {200, [], env.body}
          end

        {:ok, %{env | status: status, headers: headers, body: body}}
      end)
    end

    test "decode XMLRPC body" do
      assert {:ok, env} = Client.get("/decode")
      assert env.body == %XMLRPC.MethodResponse{param: 30}
    end

    test "do not decode empty body" do
      assert {:ok, env} = Client.get("/empty")
      assert env.body == nil
    end

    test "do not decode empty string body" do
      assert {:ok, env} = Client.get("/empty-string")
      assert env.body == ""
    end

    test "decode only if Content-Type is application/xml or test/json" do
      assert {:ok, env} = Client.get("/invalid-content-type")
      assert env.body == "hello"
    end

    test "encode body as XMLRPC" do
      sum = ~s(
      <?xml version="1.0" encoding="UTF-8"?>
      <methodCall>
         <methodName>sample.sum</methodName>
         <params>
            <param>
               <value><string>foo</string></value>
            </param>
         </params>
      </methodCall>
      )

      assert {:ok, env} = Client.post("/encode", sum)
      assert env.body == %XMLRPC.MethodCall{method_name: "sample.sum", params: ["baz"]}
    end

    test "do not encode nil body" do
      assert {:ok, env} = Client.post("/raw", nil)
      assert env.body == nil
    end

    test "do not encode binary body" do
      assert {:ok, env} = Client.post("/raw", "raw-string")
      assert env.body == "raw-string"
    end

    test "return error on encoding error" do
      assert {:error,
              {XMLRPC.Tesla.Middleware, :encode,
               {_, <<"unable to encode value: ", _rest::binary>>}}} =
               Client.post("/encode", %XMLRPC.MethodCall{params: [self()]})
    end

    test "return error when decoding invalid xml format" do
      assert {:error, {XMLRPC.Tesla.Middleware, :decode, _}} = Client.get("/invalid-xml-format")
    end

    test "raise error when decoding non-utf8 xml" do
      assert {:error, {XMLRPC.Tesla.Middleware, :decode, _}} = Client.get("/invalid-xml-encoding")
    end
  end

  describe "custom decode function" do
    defmodule CustomDecodeFunctionClient do
      use Tesla

      plug(XMLRPC.Tesla.Middleware,
        decode: fn body ->
          result = XMLRPC.decode!(body)

          case result.param do
            "OK" -> {:ok, {:ok, result}}
            "ERROR" -> {:ok, {:error, result}}
          end
        end
      )

      adapter(fn env ->
        body = ~s(<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
   <params>
      <param>
         <value><string>RESULT</string></value>
      </param>
   </params>
</methodResponse>)

        {status, headers, body} =
          case env.url do
            "/decode/ok" ->
              {200, [{"content-type", "application/xml"}], body |> String.replace("RESULT", "OK")}

            "/decode/error" ->
              {200, [{"content-type", "application/xml"}],
               body |> String.replace("RESULT", "ERROR")}
          end

        {:ok, %{env | status: status, headers: headers, body: body}}
      end)
    end

    test "decodes as ok if response contains ok" do
      assert {:ok, %{body: {:ok, %XMLRPC.MethodResponse{}}}} =
               CustomDecodeFunctionClient.get("/decode/ok")
    end

    test "decodes as error if response contains error" do
      assert {:ok, %{body: {:error, %XMLRPC.MethodResponse{}}}} =
               CustomDecodeFunctionClient.get("/decode/error")
    end
  end

  describe "custom content type" do
    defmodule CustomContentTypeClient do
      use Tesla

      plug(XMLRPC.Tesla.Middleware, decode_content_types: ["application/x-custom-xml"])

      adapter(fn env ->
        {status, headers, body} =
          case env.url do
            "/decode" ->
              body = ~s(<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
   <params>
      <param>
         <value><int>30</int></value>
      </param>
   </params>
</methodResponse>)
              {200, [{"content-type", "application/x-custom-xml"}], body}
          end

        {:ok, %{env | status: status, headers: headers, body: body}}
      end)
    end

    test "decode if Content-Type specified in :decode_content_types" do
      assert {:ok, env} = CustomContentTypeClient.get("/decode")
      assert env.body == %XMLRPC.MethodResponse{param: 30}
    end

    test "set custom request Content-Type header specified in :encode_content_type" do
      assert {:ok, env} =
               XMLRPC.Tesla.Middleware.call(
                 %Tesla.Env{body: %XMLRPC.MethodCall{method_name: "some.api", params: [1]}},
                 [],
                 encode_content_type: "application/x-other-custom-xml"
               )

      assert Tesla.get_header(env, "content-type") == "application/x-other-custom-xml"
    end
  end

  describe "Encode / Decode" do
    defmodule EncodeDecodeXMLRPCClient do
      use Tesla

      plug(XMLRPC.Tesla.Middleware.Encode)
      plug(XMLRPC.Tesla.Middleware.Decode)

      adapter(fn env ->
        {status, headers, body} =
          case env.url do
            "/foo2baz" ->
              {200, [{"content-type", "application/xml"}],
               env.body |> String.replace("foo", "baz")}
          end

        {:ok, %{env | status: status, headers: headers, body: body}}
      end)
    end

    test "EncodeJson / DecodeJson work without options" do
      assert {:ok, env} =
               EncodeDecodeXMLRPCClient.post("/foo2baz", %XMLRPC.MethodCall{params: ["foo"]})

      assert env.body == %XMLRPC.MethodCall{method_name: [], params: ["baz"]}
    end
  end
end
