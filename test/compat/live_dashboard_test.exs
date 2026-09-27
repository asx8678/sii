defmodule BootstrapCompatibility.LiveDashboardTest do
  use ExUnit.Case, async: true

  alias BootstrapCompatibility.LiveDashboard
  alias Phoenix.LiveDashboard.Helpers

  @moduletag :tmp_dir
  @fixture Path.expand("../fixtures/live_dashboard/ecto_stats_page.ex.fixture", __DIR__)
  @patched_sha256 "c7c4763ebb3663bd679b8e5cb613e168ada68a29733ccd9edbe4d862bda6586b"

  setup %{tmp_dir: dir} do
    path = Path.join(dir, "ecto_stats_page.ex")
    File.cp!(@fixture, path)
    %{path: path}
  end

  test "patches the exact upstream source to the reviewed output", %{path: path} do
    assert LiveDashboard.apply_file!(path) == :patched
    assert sha256(File.read!(path)) == @patched_sha256
  end

  test "an already patched source is unchanged, including its modification time", %{path: path} do
    assert LiveDashboard.apply_file!(path) == :patched
    File.touch!(path, 1_000_000_000)
    before = File.stat!(path)
    source = File.read!(path)
    assert LiveDashboard.apply_file!(path) == :unchanged
    assert File.read!(path) == source
    assert File.stat!(path).mtime == before.mtime
  end

  test "rejects unknown content without writing to it", %{path: path} do
    source = File.read!(path) <> "\n# unexpected source change\n"
    File.write!(path, source)

    assert_raise ArgumentError, ~r/unexpected LiveDashboard 0.9.1 source hash/, fn ->
      LiveDashboard.apply_file!(path)
    end

    assert File.read!(path) == source
  end

  test "missing source raises instead of silently skipping the fix", %{tmp_dir: dir} do
    path = Path.join(dir, "missing.ex")
    assert_raise File.Error, fn -> LiveDashboard.apply_file!(path) end
    refute File.exists?(path)
  end

  test "patched formatter compiles without Postgrex and preserves installed types and fallbacks",
       %{
         path: path
       } do
    refute Code.ensure_loaded?(Postgrex.Interval)
    assert LiveDashboard.apply_file!(path) == :patched
    module = BootstrapCompatibility.FormatterWithoutPostgrex
    formatter = compile_formatter!(path, module, Postgrex.Interval)

    assert formatter.(nil, Decimal.new("12.30")) == "12.30"
    assert formatter.(nil, Duration.new!(hour: 2)) == "2h"
    assert formatter.(:bytes, 1024) == Helpers.format_bytes(1024)
    assert formatter.(:percent, 0.12345) == "12.3"
    assert formatter.(nil, %{unchanged: true}) == %{unchanged: true}
  end

  test "patched formatter includes an available optional struct without installing Postgrex", %{
    path: path
  } do
    assert LiveDashboard.apply_file!(path) == :patched
    module = BootstrapCompatibility.FormatterWithOptionalInterval
    formatter = compile_formatter!(path, module, BootstrapCompatibility.OptionalInterval)

    assert formatter.(nil, %BootstrapCompatibility.OptionalInterval{value: "2 months"}) ==
             "2 months"

    assert formatter.(nil, Decimal.new("1.25")) == "1.25"
    refute Code.ensure_loaded?(Postgrex.Interval)
  end

  defp compile_formatter!(path, module, optional_module) do
    # Compile the actual patched clauses, not a duplicate implementation.
    source = File.read!(path)
    {first, _} = :binary.match(source, "  for module <- [Decimal,")
    {last, _} = :binary.match(source, "  defp render_error(")
    clauses = source |> binary_part(first, last - first) |> Code.string_to_quoted!()

    clauses =
      Macro.prewalk(clauses, fn
        {:__aliases__, _, [:Postgrex, :Interval]} -> optional_module
        node -> node
      end)

    quoted =
      quote do
        defmodule unquote(module) do
          import Phoenix.LiveDashboard.Helpers, only: [format_bytes: 1]
          unquote(clauses)
          def format_value(type, value), do: format(type, value)
        end
      end

    on_exit(fn ->
      :code.purge(module)
      :code.delete(module)
    end)

    {_compiled, diagnostics} = Code.with_diagnostics(fn -> Code.compile_quoted(quoted) end)
    assert diagnostics == []
    Function.capture(module, :format_value, 2)
  end

  defp sha256(source), do: :crypto.hash(:sha256, source) |> Base.encode16(case: :lower)
end
