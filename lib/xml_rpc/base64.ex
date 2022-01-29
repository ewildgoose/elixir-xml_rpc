defmodule XMLRPC.Base64 do
  @moduledoc """
  Elixir datatype to store base64 value.

  Note: See the `Base` module for other conversions in Elixir stdlib.
  """
  @type t :: %__MODULE__{raw: String.t}
  defstruct raw: ""

  @doc """
  Create a new Base64 struct from an binary input.
  """
  def new(binary) do
    %__MODULE__{raw: Base.encode64(binary)}
  end

  @doc """
  Attempt to decode a Base64 encoded value.

  Note: thin wrapper around `Base.decode64/1`.
  """
  def to_binary(%__MODULE__{raw: encoded}) do
    # Some XMLRPC libraries put whitespace in the Base64 data.
    # The <1.2.0 version of elixir won't correctly parse it.
    # We manually remove whitespace on older versions of elixir
    case encoded do
      [] -> {:ok, encoded}
      _ ->
        if Version.compare(System.version, "1.2.3") == :lt do
          encoded
          |> String.replace(~r/\s/, "") # remove any whitespace
          |> Base.decode64
        else
          Base.decode64(encoded, ignore: :whitespace)
        end
    end
  end
end
