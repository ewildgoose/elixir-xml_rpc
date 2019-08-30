defmodule XMLRPC.FormattedFloat do
  @moduledoc """
  Elixir datatype to store formatted float value

  """
  @type t :: %__MODULE__{raw: String.t()}
  defstruct raw: ""

  @doc """
  Create a new FormattedFloat struct
  """
  def new({float, pattern}) do
    %__MODULE__{raw: {float, pattern}}
  end

  @doc """
  Attempt convert struct to binary
  """
  def to_binary(%__MODULE__{raw: {float, pattern}}) do
    :io_lib.format(pattern, [float]) |> IO.iodata_to_binary()
  end
end
