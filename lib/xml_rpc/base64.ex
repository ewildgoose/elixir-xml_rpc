defmodule XMLRPC.Base64 do
  @moduledoc """
  Elixir datatype to store base64 value

  Note: See the `Base` module for other conversions in Elixir stdlib
  """
  @type t :: %__MODULE__{raw: String.t}
  defstruct raw: ""

  @doc """
  Create a new Base64 struct from an binary input
  """
  def new(binary) do
    %__MODULE__{raw: Base.encode64(binary)}
  end

  @doc """
  Attempt to decode a Base64 encoded value

  Note: thin wrapper around `Base.decode64/1`
  """
  def to_binary(%__MODULE__{raw: encoded}) do
    {:ok, Base.decode64(encoded)}
  end
end
