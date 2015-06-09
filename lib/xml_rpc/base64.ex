defmodule XMLRPC.Base64 do
  @type t :: %__MODULE__{raw: String.t}
  defstruct raw: ""

  def new(binary) do
    %__MODULE__{raw: Base.encode64(binary)}
  end

  def to_binary(%__MODULE__{raw: encoded}) do
    {:ok, Base.decode64(encoded)}
  end
end
