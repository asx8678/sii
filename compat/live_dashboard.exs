defmodule BootstrapCompatibility.LiveDashboard do
  @moduledoc """
  Applies the single reviewed LiveDashboard 0.9.1 optional-formatter fix.

  Only the exact upstream source or the exact patched source is accepted.
  See `compat/README.md` for provenance and removal conditions.
  """

  @original_sha256 "c7a8997ca63f9e671cc25b639f95dc4afc1cff58b6a669101772d2548fbd5b4a"
  @patched_sha256 "c7c4763ebb3663bd679b8e5cb613e168ada68a29733ccd9edbe4d862bda6586b"
  @original """
    defp format(_, %struct{} = value) when struct in [Decimal, Duration, Postgrex.Interval],
      do: struct.to_string(value)
  """
  @patched """
    for module <- [Decimal, Duration, Postgrex.Interval], Code.ensure_loaded?(module) do
      defp format(_, %unquote(module){} = value), do: unquote(module).to_string(value)
    end
  """

  @doc "Applies the hash-verified fix to a source file, or leaves an already patched file alone."
  @spec apply_file!(Path.t()) :: :patched | :unchanged
  def apply_file!(path) do
    source = File.read!(path)

    case sha256(source) do
      @original_sha256 ->
        patched = String.replace(source, @original, @patched, global: false)

        if sha256(patched) != @patched_sha256 do
          raise ArgumentError, "LiveDashboard compatibility patch output hash mismatch"
        end

        File.write!(path, patched)
        :patched

      @patched_sha256 ->
        :unchanged

      _ ->
        raise ArgumentError, "unexpected LiveDashboard 0.9.1 source hash: #{path}"
    end
  end

  defp sha256(source), do: :crypto.hash(:sha256, source) |> Base.encode16(case: :lower)
end
