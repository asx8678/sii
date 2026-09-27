defmodule Si.TaskCheckProbe do
  @moduledoc "Temporary gate probe."

  @doc "Returns the probe value."
  @spec value() :: :x
  def value do
    IO.inspect(:x)
  end
end
