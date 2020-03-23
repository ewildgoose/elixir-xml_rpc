if Code.ensure_loaded?(Tesla) do
  defmodule XMLRPC.Tesla.Middleware do
    @moduledoc """
    Tesla Middleware that encodes and decodes XMLRPC

    ## Example usage
    ```
    defmodule MyClient do
      use Tesla
      plug XMLRPC.Tesla.Middleware
      # or custom functions allowing to post process
      plug Tesla.Middleware.JSON, decode: &XMLRPC.decode/1, encode: &XMLRPC.encode/1
    end
    ```
    ## Options
    - `:decode` - decoding function
    - `:encode` - encoding function
    - `:encode_content_type` - content-type to be used in request header
    - `:engine_opts` - optional engine (XMLRPC) options
    - `:decode_content_types` - list of additional decodable content-types
    - `:decodable_status` - status function to be decodable (default 200..299)
    """

    @behaviour Tesla.Middleware

    @default_encode_content_type "application/xml"
    @default_content_types ["application/xml"]
    def default_decodable_status(status), do: status in 200..299

    @impl Tesla.Middleware
    def call(env, next, opts) do
      opts = opts || []

      with {:ok, env} <- encode(env, opts),
           {:ok, env} <- Tesla.run(env, next) do
        decode(env, opts)
      end
    end

    @doc """
    Encodes request body as XMLRPC.
    It is used by `XMLRPC.Tesla.Middleware.Encode`.
    """
    def encode(env, opts) do
      with true <- encodable?(env, opts),
           {:ok, body} <- encode_body(env.body, opts) do
        {:ok,
         env
         |> Tesla.put_body(body)
         |> Tesla.put_headers([{"content-type", encode_content_type(opts)}])}
      else
        false -> {:ok, env}
        error -> error
      end
    end

    @doc """
    Decodes request body as XMLRPC.
    It is used by `XMLRPC.Tesla.Middleware.Decode`.
    """
    def decode(env, opts) do
      with true <- decodable?(env, opts),
           {:ok, body} <- decode_body(env.body, opts) do
        {:ok, %{env | body: body}}
      else
        false -> {:ok, env}
        error -> error
      end
    end

    defp encode_body(body, opts), do: process(body, :encode, opts)

    defp encode_content_type(opts),
      do: Keyword.get(opts, :encode_content_type, @default_encode_content_type)

    defp encodable?(%{body: nil}, _opts), do: false
    defp encodable?(%{body: body}, _opts) when is_binary(body), do: false
    defp encodable?(%{body: %XMLRPC.MethodCall{}}, _opts), do: true

    defp encodable?(_env, _opts), do: false

    defp decodable?(env, opts),
      do:
        decodable_content_type?(env, opts) &&
          decodable_status?(env, opts) &&
          decodable_body?(env)

    def decodable_status?(env, opts) do
      f = Keyword.get(opts, :decodable_status, &__MODULE__.default_decodable_status/1)
      f.(env.status)
    end

    defp decodable_content_type?(env, opts) do
      case Tesla.get_header(env, "content-type") do
        nil ->
          false

        content_type ->
          Enum.any?(content_types(opts), &String.starts_with?(content_type, &1))
      end
    end

    defp content_types(opts),
      do: @default_content_types ++ Keyword.get(opts, :decode_content_types, [])

    defp decodable_body?(env) do
      is_binary(env.body) && env.body != ""
    end

    defp decode_body(body, opts), do: process(body, :decode, opts)

    defp process(data, op, opts) do
      case do_process(data, op, opts) do
        {:ok, data} -> {:ok, data}
        {:error, reason} -> {:error, {__MODULE__, op, reason}}
        {:error, reason, _pos} -> {:error, {__MODULE__, op, reason}}
      end
    rescue
      ex in Protocol.UndefinedError ->
        {:error, {__MODULE__, op, ex}}
    end

    defp do_process(data, op, opts) do
      if f = opts[op] do
        f.(data)
      else
        opts = Keyword.get(opts, :engine_opts, [])
        apply(XMLRPC, op, [data, opts])
      end
    end
  end

  defmodule XMLRPC.Tesla.Middleware.Decode do
    @moduledoc """
    Middleware that only decodes XMLRPC
    """
    def call(env, next, opts) do
      opts = opts || []

      with {:ok, env} <- Tesla.run(env, next) do
        XMLRPC.Tesla.Middleware.decode(env, opts)
      end
    end
  end

  defmodule XMLRPC.Tesla.Middleware.Encode do
    @moduledoc """
    Middleware that only decodes XMLRPC
    """
    def call(env, next, opts) do
      opts = opts || []

      with {:ok, env} <- XMLRPC.Tesla.Middleware.encode(env, opts) do
        Tesla.run(env, next)
      end
    end
  end
end
