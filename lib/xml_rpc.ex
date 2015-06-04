defmodule XMLRPC do

  defmodule Fault do
    @type t :: %__MODULE__{fault_code: Integer, fault_string: String.t}
    defstruct fault_code: 0, fault_string: ""
  end

  defmodule MethodCall do
    @type t :: %__MODULE__{method_name: String.t, params: [ Integer|Float|String.t|map()|[Integer|Float|String.t] ]}
    defstruct method_name: "", params: nil
  end

  defmodule MethodResponse do
    @type t :: %__MODULE__{param: Integer|Float|String.t|map()|[Integer|Float|String.t]}
    defstruct param: nil
  end

end
