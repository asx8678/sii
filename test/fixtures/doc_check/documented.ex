defmodule Si.DocFixtures.Documented do
  @moduledoc "Documented checker fixture."

  @doc "Doubles an integer."
  @spec double(integer()) :: integer()
  def double(value), do: value * 2

  @doc "Returns an expression unchanged."
  @spec identity(Macro.t()) :: Macro.t()
  defmacro identity(value), do: value
end
