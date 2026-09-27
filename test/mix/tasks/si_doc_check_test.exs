defmodule Mix.Tasks.Si.DocCheckTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  alias Mix.Tasks.Si.DocCheck

  @moduletag :tmp_dir
  @fixtures Path.expand("../../fixtures/doc_check", __DIR__)
  @task_source Path.expand("../../..", __DIR__) |> Path.join("lib/mix/tasks/si.doc_check.ex")

  setup %{tmp_dir: dir} do
    # Other tests enter temporary Mix projects. Consume their pending app header
    # before capturing this task's own output; do not hide any task diagnostics.
    Mix.shell().print_app()
    beams = Path.join(dir, "beams")
    File.mkdir_p!(beams)
    true = Code.prepend_path(beams)
    on_exit(fn -> Code.delete_path(beams) end)
    %{beams: beams}
  end

  test "compiled documented functions and translated macro specs pass and files deduplicate",
       context do
    path = Path.join(@fixtures, "documented.ex")
    compile!([path], context.beams)

    assert capture_io(fn -> assert DocCheck.run([path, path]) == :ok end) ==
             "ok: 1 modules, 2 functions\n"
  end

  test "undocumented fixture reports each exact missing attribute", context do
    path = Path.join(@fixtures, "undocumented.ex")
    compile!([path], context.beams)

    assert errors([path]) == """
           Si.DocFixtures.Undocumented: missing @moduledoc
           Si.DocFixtures.Undocumented.combine/2: missing @doc
           Si.DocFixtures.Undocumented.combine/2: missing @spec
           """
  end

  test "hidden module is noted and excluded", context do
    path =
      source!(context, "hidden", """
      defmodule Si.DocFixtures.Hidden do
        @moduledoc false
        def undocumented, do: :ok
      end
      """)

    compile!([path], context.beams)

    assert capture_io(fn -> DocCheck.run([path]) end) ==
             "note: Si.DocFixtures.Hidden: @moduledoc false (skipped)\nok: 0 modules, 0 functions\n"
  end

  test "doc false and impl true exempt functions even with explicit callback docs", context do
    behaviour =
      source!(context, "behaviour", """
      defmodule Si.DocFixtures.Behaviour do
        @moduledoc "Callback fixture."
        @callback handle(integer()) :: integer()
      end
      """)

    callback =
      source!(context, "callback", """
      defmodule Si.DocFixtures.Callback do
        @moduledoc "Implementation fixture."
        @behaviour Si.DocFixtures.Behaviour
        @impl true
        @doc "A callback with deliberately no function spec."
        def handle(value) when is_integer(value), do: value
        @doc false
        def hidden(value), do: value
        @doc false
        defmacro hidden_macro(value), do: value
      end
      """)

    compile!([behaviour, callback], context.beams)
    assert capture_io(fn -> DocCheck.run([callback]) end) == "ok: 1 modules, 0 functions\n"
  end

  test "functions and macros independently require docs and specs", context do
    path =
      source!(context, "partial", """
      defmodule Si.DocFixtures.Partial do
        @moduledoc "Partially documented fixture."
        @doc "No spec."
        def doc_only(value), do: value
        @spec spec_only(integer()) :: integer()
        def spec_only(value), do: value
        defmacro missing(value), do: value
      end
      """)

    compile!([path], context.beams)

    assert errors([path]) == """
           Si.DocFixtures.Partial.doc_only/1: missing @spec
           Si.DocFixtures.Partial.spec_only/1: missing @doc
           Si.DocFixtures.Partial.missing/1: missing @doc
           Si.DocFixtures.Partial.missing/1: missing @spec
           """
  end

  test "nested module names resolve within their containing module", context do
    path =
      source!(context, "nested", """
      defmodule Si.DocFixtures.Outer do
        @moduledoc "Outer fixture."
        defmodule Inner do
          @moduledoc "Inner fixture."
          @doc "Returns ok."
          @spec value() :: :ok
          def value, do: :ok
        end
      end
      """)

    compile!([path], context.beams)
    assert capture_io(fn -> DocCheck.run([path]) end) == "ok: 2 modules, 1 functions\n"
  end

  test "missing BEAM documentation is a visible failure, not a successful empty scan", context do
    path =
      source!(context, "unavailable", """
      defmodule Si.DocFixtures.Unavailable do
      end
      """)

    assert errors([path]) ==
             "Si.DocFixtures.Unavailable: cannot fetch documentation (:module_not_found)\n"
  end

  test "usage exits 2 without compiling", _context do
    assert capture_io(:stderr, fn ->
             assert catch_exit(DocCheck.run([])) == {:shutdown, 2}
           end) == "usage: mix si.doc_check FILE...\n"
  end

  test "real Mix CLI compiles when necessary and returns success, problem and usage exit codes",
       %{tmp_dir: dir} do
    project = Path.join(dir, "project")
    File.mkdir_p!(Path.join(project, "lib/mix/tasks"))
    File.cp!(@task_source, Path.join(project, "lib/mix/tasks/si.doc_check.ex"))
    File.cp!(Path.join(@fixtures, "documented.ex"), Path.join(project, "lib/documented.ex"))
    File.cp!(Path.join(@fixtures, "undocumented.ex"), Path.join(project, "lib/undocumented.ex"))

    File.write!(Path.join(project, "mix.exs"), """
    defmodule DocCheckCLI.MixProject do
      use Mix.Project
      def project, do: [app: :doc_check_cli, version: "0.0.0"]
    end
    """)

    {output, status} = cli(project, ["lib/documented.ex"])
    assert status == 0
    assert output =~ "Compiling 3 files"
    assert output =~ "ok: 1 modules, 2 functions"
    refute output =~ "warning"
    {output, status} = cli(project, ["lib/undocumented.ex"])
    assert status == 1
    assert output =~ "Si.DocFixtures.Undocumented.combine/2: missing @spec"
    refute output =~ "ok:"
    {output, status} = cli(project, [])
    assert status == 2
    assert output == "usage: mix si.doc_check FILE...\n"
  end

  defp compile!(files, beams) do
    # Mix test disables docs while compiling tests; these fixtures need real BEAM metadata.
    previous = Code.compiler_options(docs: true, debug_info: true)

    {status, modules, diagnostics} =
      try do
        Kernel.ParallelCompiler.compile_to_path(files, beams, return_diagnostics: true)
      after
        Code.compiler_options(previous)
      end

    on_exit(fn ->
      for module <- modules, is_atom(module) do
        :code.delete(module)
        :code.purge(module)
      end
    end)

    warnings = diagnostics.compile_warnings ++ diagnostics.runtime_warnings
    assert {:ok, ^modules, []} = {status, modules, warnings}
  end

  defp source!(context, name, text) do
    path = Path.join(context.tmp_dir, name <> ".ex")
    File.write!(path, text)
    path
  end

  defp errors(paths) do
    capture_io(:stderr, fn -> assert catch_exit(DocCheck.run(paths)) == {:shutdown, 1} end)
  end

  defp cli(project, args) do
    System.cmd("mix", ["si.doc_check" | args],
      cd: project,
      stderr_to_stdout: true,
      env: [
        {"MIX_ENV", "test"},
        {"MIX_EXS", nil},
        {"MIX_BUILD_PATH", Path.join(project, "_build")}
      ]
    )
  end
end
