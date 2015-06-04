defmodule XMLRPC do

  defmodule Fault do
    defstruct fault_code: 0, fault_string: ""
  end

  defmodule MethodCall do
    defstruct method_name: "", parameters: nil
  end

  defmodule MethodResponse do
    defstruct parameter: nil
  end

end
