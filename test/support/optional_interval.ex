defmodule BootstrapCompatibility.OptionalInterval do
  @moduledoc false
  defstruct [:value]

  @doc false
  @spec to_string(%__MODULE__{value: String.t()}) :: String.t()
  def to_string(%__MODULE__{value: value}), do: value
end
