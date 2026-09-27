defmodule Si.CITest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir
  @ci Path.expand("../../bin/ci", __DIR__)

  setup %{tmp_dir: dir} do
    project = Path.join(dir, "project with spaces")
    bin = Path.join(project, "bin")
    fake_bin = Path.join(dir, "fake-bin")
    File.mkdir_p!(bin)
    File.mkdir_p!(fake_bin)
    File.cp!(@ci, Path.join(bin, "ci"))

    executable!(Path.join(fake_bin, "mix"), """
    #!/usr/bin/env bash
    set -eu
    test "$PWD" = "$CI_ROOT"
    printf 'mix %s\\n' "$*" >> "$CI_TRACE"
    if [[ "${FAIL_STEP:-}" == "mix:$1" ]]; then exit "${FAIL_CODE:-2}"; fi
    exit 0
    """)

    executable!(Path.join(fake_bin, "npm"), """
    #!/usr/bin/env bash
    set -eu
    printf 'npm %s %s\\n' "${PWD#"$CI_ROOT"/}" "$*" >> "$CI_TRACE"
    if [[ "${FAIL_STEP:-}" == "npm" ]]; then exit "${FAIL_CODE:-2}"; fi
    exit 0
    """)

    executable!(Path.join(bin, "contract-test"), """
    #!/usr/bin/env bash
    printf 'contract\\n' >> "$CI_TRACE"
    exit "${CONTRACT_EXIT:-0}"
    """)

    %{project: project, fake_bin: fake_bin, trace: Path.join(dir, "trace")}
  end

  test "default sequence is exact, independent of caller cwd, with no optional packages",
       context do
    assert {output, 0} = run_ci(context)
    assert steps(output) == ["format", "compile", "credo", "test"]
    assert String.ends_with?(output, "\nPASS\n")

    assert trace(context) == [
             "mix format --check-formatted",
             "mix compile --warnings-as-errors",
             "mix credo --strict",
             "mix test --warnings-as-errors"
           ]
  end

  test "full mode preserves package order, all npm commands, tag includes and contract last",
       context do
    packages = ["bridge", "testing/pi-faux", "adapter"]

    for package <- packages do
      path = Path.join(context.project, package)
      File.mkdir_p!(path)
      File.write!(Path.join(path, "package.json"), "{}")
    end

    assert {output, 0} = run_ci(context, ["--full"])
    assert steps(output) == ["format", "compile", "credo", "test" | packages] ++ ["contract"]
    assert String.ends_with?(output, "\nPASS\n")

    assert trace(context) ==
             [
               "mix format --check-formatted",
               "mix compile --warnings-as-errors",
               "mix credo --strict",
               "mix test --warnings-as-errors --include slow --include pi"
             ] ++
               Enum.flat_map(packages, fn package ->
                 for command <- [
                       "ci --silent",
                       "run --silent lint",
                       "run --silent typecheck --if-present",
                       "run --silent test --if-present"
                     ],
                     do: "npm #{package} #{command}"
               end) ++ ["contract"]
  end

  for {step, code} <- [{"format", 1}, {"compile", 7}, {"credo", 3}, {"test", 2}] do
    @tag failure_step: step, failure_code: code
    test "#{step} failure #{code} becomes exit 1 without PASS", context do
      assert {output, 1} =
               run_ci(context, [], [
                 {"FAIL_STEP", "mix:#{context.failure_step}"},
                 {"FAIL_CODE", "#{context.failure_code}"}
               ])

      refute output =~ "PASS"
      assert List.last(steps(output)) == context.failure_step
    end
  end

  test "a failed npm subshell and failed full contract also normalize to 1", context do
    package = Path.join(context.project, "adapter")
    File.mkdir_p!(package)
    File.write!(Path.join(package, "package.json"), "{}")
    assert {output, 1} = run_ci(context, [], [{"FAIL_STEP", "npm"}, {"FAIL_CODE", "2"}])
    refute output =~ "PASS"
    assert List.last(steps(output)) == "adapter"
    assert {output, 1} = run_ci(context, ["--full"], [{"CONTRACT_EXIT", "7"}])
    refute output =~ "PASS"
    assert List.last(steps(output)) == "contract"
  end

  defp run_ci(context, args \\ [], extra_env \\ []) do
    System.cmd("bash", [Path.join(context.project, "bin/ci") | args],
      cd: context.tmp_dir,
      stderr_to_stdout: true,
      env:
        [
          {"PATH", context.fake_bin <> ":" <> System.fetch_env!("PATH")},
          {"CI_ROOT", context.project},
          {"CI_TRACE", context.trace},
          {"FAIL_STEP", nil},
          {"FAIL_CODE", nil},
          {"CONTRACT_EXIT", nil}
        ] ++ extra_env
    )
  end

  defp steps(output) do
    for "==> " <> step <- String.split(output, "\n"), do: step
  end

  defp trace(context), do: context.trace |> File.read!() |> String.split("\n", trim: true)

  defp executable!(path, text) do
    File.write!(path, text)
    File.chmod!(path, 0o755)
  end
end
