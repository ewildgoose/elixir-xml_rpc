defmodule XMLRPC.DateTime do
  @moduledoc """
  Struct to store a date-time in xml-rpc format (a variation on ISO 8601).

  Note, there is significant ambiguity in the formatting of date-time in xml-rpc.
  This is a thin wrapper around a basic parser, but knowledge of the API you are
  trying to connect to will be valuable.  Consider writing your own decoder
  (and perhaps encoder) to speak to non standard end-points...
  """

  @type t :: %__MODULE__{raw: String.t}
  defstruct raw: ""

  @doc """
  Create a new datetime in the (odd) format that the XMLRPC spec claims is ISO 8601.

      iex> XMLRPC.DateTime.new({{2015,6,9},{9,7,2}})
      %XMLRPC.DateTime{raw: "20150609T09:07:02"}

  """
  def new({{year, month, day},{hour, min, sec}}) do
    date = :io_lib.format("~4.10.0B~2.10.0B~2.10.0BT~2.10.0B:~2.10.0B:~2.10.0B",
                            [year, month, day, hour, min, sec])
           |> IO.iodata_to_binary
    %__MODULE__{raw: date}
  end

  @doc """
  Attempt to parse a returned date. Note there is significant ambiguity around
  what constitutes an valid date... The spec says no hyphens between date parts
  and no timezone. However, servers in the field sometimes seem to return
  ISO 8601 dates...

  We attempt to be generous in parsing, but no attempt is made to handle timezones.
  For more accurate parsing, including handling timezones, see the Calendar library

      iex>XMLRPC.DateTime.to_erlang_date(%XMLRPC.DateTime{raw: "20150609T09:07:02"})
      {:ok, {{2015, 6, 9}, {9, 7, 2}}}

  """
  def to_erlang_date(%__MODULE__{raw: date}) do
    case Regex.run(~r/(\d{4})-?(\d{2})-?(\d{2})T(\d{2}):(\d{2}):(\d{2})/, date, capture: :all_but_first) do
      nil ->  {:error, "Unable to parse date"}
      date -> [year, mon, day, hour, min, sec] =
                  date
                  |> Enum.map(&to_int/1)
              {:ok, {{year, mon, day}, {hour, min, sec}}}
    end
  end

  defp to_int(str), do: str |> Integer.parse |> elem(0)
end
