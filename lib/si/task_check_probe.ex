defmodule Si.TaskCheckProbe do
  @moduledoc "Temporary gate probe."

  @doc "Returns the probe value."
  @spec value() :: :x
  def value do
    :x
  end

  def undocumented(value), do: value
end
