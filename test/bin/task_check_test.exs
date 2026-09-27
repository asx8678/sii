defmodule Si.TaskCheckTest do
  use ExUnit.Case, async: false

  @moduletag :tmp_dir
  @fixtures Path.expand("../fixtures/task_check", __DIR__)
  @script Path.expand("../../bin/task-check", __DIR__)
  @task "final_plan/tasks/M99/T99.01-fixture.md"
  @note "final_plan/status/T99.01.md"
  @fields [
    "Branch",
    "Summary",
    "Files",
    "Tests added",
    "Acceptance criteria",
    "Verify",
    "After implementing",
    "Deliberate break",
    "task-check",
    "bin/ci",
    "Redo history",
    "Deviations",
    "Follow-ups"
  ]
  @cases File.read!(Path.join(@fixtures, "hygiene.txt")) |> String.split("\n", trim: true)

  setup %{tmp_dir: dir} do
    write!(dir, ".gitignore", "tmp/\n")
    write!(dir, @task, File.read!(Path.join(@fixtures, "task.md")))
    write!(dir, "final_plan/tasks.yaml", "tasks:\n  - id: T99.01\n    status: in_progress\n")
    write!(dir, "bin/task-check", File.read!(@script), 0o755)
    write!(dir, "bin/ci", File.read!(Path.join(@fixtures, "ci.sh")), 0o755)

    for command <- ["mix", "pgrep"] do
      write!(dir, "tools/#{command}", File.read!(Path.join(@fixtures, "#{command}.sh")), 0o755)
    end

    git!(dir, ["init", "-b", "main"])
    git!(dir, ["config", "user.name", "Task checker fixture"])
    git!(dir, ["config", "user.email", "fixture@example.invalid"])
    git!(dir, ["config", "commit.gpgsign", "false"])
    git!(dir, ["config", "core.hooksPath", "/dev/null"])
    commit!(dir)
    git!(dir, ["checkout", "-b", "task/T99.01-fixture"])
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  test "all ordered gates pass with empty doc/test sets and stdout mirrors the report", %{
    dir: dir
  } do
    assert {output, 0} = check(dir)

    assert gates(output) == [
             "task",
             "branch",
             "clean",
             "scope",
             "hygiene",
             "ci",
             "docs",
             "tests",
             "leftovers"
           ]

    assert output == File.read!(Path.join(dir, "tmp/task-check/T99.01.txt"))
    sha = git!(dir, ["rev-parse", "HEAD"]) |> String.trim()
    assert String.starts_with?(output, "task-check T99.01 HEAD #{sha} final=no\n")
    assert String.ends_with?(output, "RESULT: PASS\n")
    refute File.exists?(Path.join(dir, "tmp/trace"))
  end

  test "usage and invalid arguments exit 2; explicit ID still checks branch", %{dir: dir} do
    git!(dir, ["checkout", "main"])
    assert {"usage: bin/task-check [--final] [ID]\n", 2} = check(dir)

    for args <- [["--bad"], ["T99.01", "T99.01"], ["../bad"], ["--final", "--final"]] do
      assert {"usage: bin/task-check [--final] [ID]\n", 2} = check(dir, args)
    end

    assert {output, 1} = check(dir, ["T99.01"])
    assert output =~ "branch FAIL"
    assert output =~ "leftovers PASS"
  end

  test "missing task, wrong branch and dirty tree accumulate rather than stopping", %{dir: dir} do
    write!(dir, "dirty.txt", "untracked")
    assert {output, 1} = check(dir, ["T99.02"])
    assert output =~ "task FAIL"
    assert output =~ "branch FAIL"
    assert output =~ "clean FAIL"
    assert output =~ "ci PASS"
    assert output =~ "tests FAIL"
    assert output =~ "RESULT: FAIL (task branch clean tests)"
  end

  test "a moved main fails ancestry", %{dir: dir} do
    git!(dir, ["checkout", "main"])
    write!(dir, "moved.txt", "main moved")
    commit!(dir)
    git!(dir, ["checkout", "task/T99.01-fixture"])
    assert {output, 1} = check(dir)
    assert output =~ "branch FAIL"
  end

  test "scope supports exact paths, declared directories and module names but warns on others", %{
    dir: dir
  } do
    write!(dir, "lib/declared/child.ex", "defmodule Fixture.Child do\nend\n")
    write!(dir, "lib/renamed.ex", "defmodule Fixture.Named do\nend\n")
    write!(dir, "test/named_helper.exs", "defmodule Fixture.Named do\nend\n")
    write!(dir, "extra.txt", "extra")
    commit!(dir)
    assert {output, 0} = check(dir)
    assert output =~ "scope WARN extra.txt\n"
    assert output =~ "docs PASS no changed"
  end

  for {line, index} <- Enum.with_index(@cases, 1) do
    [level, path, text] = String.split(line, "|", parts: 3)
    @tag expected_level: level, input_path: path, input_text: text
    test "hygiene fixture #{index}", context do
      write!(context.dir, context.input_path, context.input_text <> "\n")
      commit!(context.dir)
      {output, status} = check(context.dir)
      assert status == if(context.expected_level == "FAIL", do: 1, else: 0)
      assert output =~ "hygiene #{context.expected_level}"
      if context.expected_level != "PASS", do: assert(output =~ "#{context.input_path}:1:")
    end
  end

  test "hygiene scans only added lines with new line numbers and honors exact exemptions", %{
    dir: dir
  } do
    [_level, _path, forbidden] = String.split(hd(@cases), "|", parts: 3)

    exempt = [
      "final_plan/example.md",
      "docs/example.md",
      "AGENTS.md",
      ".credo.exs",
      "mix.lock",
      "package-lock.json",
      "bridge/package-lock.json",
      "test/fixtures/example.txt",
      "evals/example.txt",
      "lib/si/checks/test_integrity/example.txt",
      "test/si/checks/test_integrity_test.exs"
    ]

    for path <- exempt, do: write!(dir, path, forbidden)
    write!(dir, "notes.txt", "one\ntwo\n#{forbidden}\n")
    commit!(dir)
    assert {output, 1} = check(dir)
    assert output =~ "notes.txt:3:"
    for path <- exempt, do: refute(output =~ "#{path}:1:")
    git!(dir, ["branch", "-f", "main", "HEAD"])
    write!(dir, "notes.txt", "one\ntwo\n")
    commit!(dir)
    assert {output, 0} = check(dir)
    assert output =~ "hygiene PASS"
  end

  test "hunk content cannot masquerade as a path header and exemption names are exact", %{
    dir: dir
  } do
    [_level, _path, forbidden] = String.split(hd(@cases), "|", parts: 3)
    write!(dir, "notes.txt", "++ b/final_plan/not-a-header.md\n" <> forbidden)
    write!(dir, "other/package-lockxjson", forbidden)
    commit!(dir)
    assert {output, 1} = check(dir)
    assert output =~ "notes.txt:2:"
    assert output =~ "other/package-lockxjson:1:"
  end

  test "secret-shaped values fail at word starts, are redacted, and task IDs do not match", %{
    dir: dir
  } do
    for {prefix, length} <- [{"sk-", 20}, {"xai-", 20}, {"ghp_", 30}] do
      value = prefix <> String.duplicate("A", length)
      write!(dir, "notes.txt", "token=" <> value)
      commit!(dir)
      assert {output, 1} = check(dir)
      assert output =~ "possible secret (value redacted)"
      refute output =~ value
    end

    write!(dir, "notes.txt", "task-" <> String.duplicate("A", 40))
    commit!(dir)
    assert {output, 0} = check(dir)
    assert output =~ "hygiene PASS"
  end

  test "private-key markers are redacted and embedded word prefixes do not match", %{dir: dir} do
    marker = "-----" <> "BEGIN TEST PRIVATE KEY" <> "-----"
    write!(dir, "notes.txt", marker)
    commit!(dir)
    assert {output, 1} = check(dir)
    assert output =~ "possible secret (value redacted)"
    refute output =~ marker
    write!(dir, "notes.txt", "word_sk-" <> String.duplicate("A", 40))
    commit!(dir)
    assert {output, 0} = check(dir)
    assert output =~ "hygiene PASS"
  end

  test "CI failures report the failing step and last 30 lines and skip docs/tests", %{dir: dir} do
    write!(dir, "lib/si/changed.ex", "defmodule Fixture.Changed do\nend\n")
    declare!(dir, "### Tests\n`test/required_test.exs`\n")
    commit!(dir)
    assert {output, 1} = check(dir, [], %{"TC_CI_FAIL" => "1"})
    assert output =~ "ci FAIL exit=2 ==> test"
    assert output =~ "log-line-6;"
    assert output =~ "log-line-35;"
    refute output =~ "log-line-5;"
    assert output =~ "docs SKIP ci failed"
    assert output =~ "tests SKIP ci failed"
    assert output == File.read!(Path.join(dir, "tmp/task-check/T99.01.txt"))
    refute File.exists?(Path.join(dir, "tmp/trace"))
  end

  test "section extraction selects nested declarations, deduplicates, and ignores incidental paths",
       %{dir: dir} do
    declare!(dir, """
    ### Deliverables
    `test/first_test.exs`, `bridge/test/example.ts`.
    #### Nested deliverables
    `test/first_test.exs` again; `adapter/test/example.ts`.
    ### Specification
    Incidental `test/ignored_test.exs` and `test/si/checks/test_integrity_test.exs`.
    ### Tests
    `test/second_test.exs`; `testing/pi-faux/test/example.ts`.
    #### Details
    `test/first_test.exs`
    ### Verify
    ```bash
    # This is not a markdown section
    mix test test/second_test.exs
    ```
    ### Other
    `test/also_ignored_test.exs`
    """)

    for path <- [
          "test/first_test.exs",
          "test/second_test.exs",
          "bridge/test/example.ts",
          "adapter/test/example.ts",
          "testing/pi-faux/test/example.ts"
        ] do
      write!(dir, path, "# fixture data\n")
    end

    commit!(dir)
    assert {output, 0} = check(dir)
    assert output =~ "tests PASS 5 declared paths; 2 repeated, 0 once"

    assert trace(dir) == [
             "test test/first_test.exs test/second_test.exs --include slow --include pi --warnings-as-errors --repeat-until-failure 3"
           ]
  end

  test "missing declared tests fail even when incidental exemption paths are ignored", %{dir: dir} do
    declare!(
      dir,
      "### Specification\nIncidental `test/ignored_test.exs`.\n### Tests\n`test/missing_test.exs`\n"
    )

    commit!(dir)
    assert {output, 1} = check(dir)
    assert output =~ "tests FAIL test/missing_test.exs: missing declared test"
    refute output =~ "test/ignored_test.exs: missing"
  end

  test "docs target only changed existing lib/si source; contract/chaos run once and others repeat",
       %{dir: dir} do
    write!(dir, "lib/si/check.ex", "defmodule Fixture.Check do\nend\n")
    write!(dir, "lib/si_web/check.ex", "defmodule Fixture.Web do\nend\n")
    write!(dir, "test/regular_test.exs", "defmodule Fixture.Regular do\nend\n")

    write!(
      dir,
      "test/contract_test.exs",
      "defmodule Fixture.Contract do\n  @moduletag :contract\nend\n"
    )

    write!(
      dir,
      "test/chaos_test.exs",
      "defmodule Fixture.Chaos do\n  @moduletag chaos: true\nend\n"
    )

    declare!(
      dir,
      "### Tests\n`test/regular_test.exs` `test/contract_test.exs` `test/chaos_test.exs`\n"
    )

    commit!(dir)
    assert {output, 0} = check(dir)
    assert output =~ "tests PASS 3 declared paths; 1 repeated, 2 once"

    assert trace(dir) == [
             "si.doc_check lib/si/check.ex",
             "test test/regular_test.exs --include slow --include pi --warnings-as-errors --repeat-until-failure 3",
             "test test/contract_test.exs test/chaos_test.exs --include slow --include pi --warnings-as-errors"
           ]
  end

  test "doc and test failures accumulate, with leftovers still inspected", %{dir: dir} do
    write!(dir, "lib/si/check.ex", "defmodule Fixture.Check do\nend\n")
    write!(dir, "test/required_test.exs", "# fixture\n")
    declare!(dir, "### Tests\n`test/required_test.exs`\n")
    commit!(dir)
    assert {output, 1} = check(dir, [], %{"TC_DOCS_FAIL" => "1", "TC_TEST_FAIL" => "1"})
    assert output =~ "docs FAIL"
    assert output =~ "tests FAIL"
    assert output =~ "leftovers PASS"
    assert output =~ "RESULT: FAIL (docs tests)"
  end

  for flag <- ["TC_PROCESS_LEAK", "TC_PROCESS_ERROR", "TC_REF_LEAK", "TC_WORKTREE_LEAK"] do
    @tag leak_flag: flag
    test "leftovers detect #{flag}", %{dir: dir, leak_flag: flag} do
      write!(dir, "test/required_test.exs", "# fixture\n")
      declare!(dir, "### Tests\n`test/required_test.exs`\n")
      commit!(dir)
      assert {output, 1} = check(dir, [], %{flag => "1"})
      assert output =~ "leftovers FAIL"
      assert output =~ "RESULT: FAIL (leftovers)"
    end
  end

  test "final requires committed note fields and committed done status, not working-tree promises",
       %{dir: dir} do
    assert {output, 1} = check(dir, ["--final"])
    assert output =~ "final FAIL"
    write!(dir, @note, note())
    write!(dir, "final_plan/tasks.yaml", "tasks:\n  - id: T99.01\n    status: done\n")
    assert {output, 1} = check(dir, ["--final"])
    assert output =~ "clean FAIL"
    assert output =~ "missing from HEAD"
    commit!(dir)
    assert {output, 0} = check(dir, ["--final"])
    assert List.last(gates(output)) == "final"
    assert output =~ "final=yes\n"
    assert output =~ "final PASS"
    write!(dir, @note, String.replace(note(), "- Verify: evidence\n", ""))
    commit!(dir)
    assert {output, 1} = check(dir, ["--final"])
    assert output =~ "missing Verify"
  end

  test "every completion field and the title are required, and committed in-progress is rejected",
       %{dir: dir} do
    write!(dir, "final_plan/tasks.yaml", "tasks:\n  - id: T99.01\n    status: done\n")

    for field <- @fields do
      write!(dir, @note, String.replace(note(), "- #{field}: evidence\n", ""))
      commit!(dir)
      assert {output, 1} = check(dir, ["--final"])
      assert output =~ "missing #{field}"
    end

    write!(dir, @note, String.replace(note(), "# T99.01 · Fixture", "# Other"))
    commit!(dir)
    assert {output, 1} = check(dir, ["--final"])
    assert output =~ "missing task title"
    write!(dir, @note, note())
    write!(dir, "final_plan/tasks.yaml", "tasks:\n  - id: T99.01\n    status: in_progress\n")
    commit!(dir)
    assert {output, 1} = check(dir, ["--final"])
    assert output =~ "T99.01 is not done in HEAD"
  end

  defp check(dir, args \\ [], overrides \\ %{}) do
    env =
      Map.new(git_env())
      |> Map.merge(%{
        "PATH" => Path.join(dir, "tools") <> ":" <> System.fetch_env!("PATH"),
        "TASK_CHECK_TRACE" => Path.join(dir, "tmp/trace"),
        "TC_CI_FAIL" => "0",
        "TC_DOCS_FAIL" => "0",
        "TC_TEST_FAIL" => "0",
        "TC_PROCESS_LEAK" => "0",
        "TC_PROCESS_ERROR" => "0",
        "TC_REF_LEAK" => "0",
        "TC_WORKTREE_LEAK" => "0"
      })
      |> Map.merge(overrides)

    System.cmd("bash", [Path.join(dir, "bin/task-check") | args],
      cd: dir,
      env: Map.to_list(env),
      stderr_to_stdout: true
    )
  end

  defp gates(output) do
    output
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      case String.split(line, " ", parts: 3) do
        [gate, status, _] when status in ["PASS", "WARN", "FAIL", "SKIP"] -> [gate]
        _ -> []
      end
    end)
  end

  defp declare!(dir, text), do: write!(dir, @task, "# T99.01 · Fixture\n\n" <> text)
  defp note, do: "# T99.01 · Fixture\n\n" <> Enum.map_join(@fields, "", &"- #{&1}: evidence\n")

  defp trace(dir),
    do: Path.join(dir, "tmp/trace") |> File.read!() |> String.split("\n", trim: true)

  defp write!(dir, relative, text, mode \\ 0o644) do
    path = Path.join(dir, relative)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, text)
    File.chmod!(path, mode)
  end

  defp commit!(dir) do
    git!(dir, ["add", "."])
    git!(dir, ["commit", "-m", "fixture"])
  end

  defp git!(dir, args) do
    {output, status} = System.cmd("git", args, cd: dir, env: git_env(), stderr_to_stdout: true)
    assert status == 0, output
    output
  end

  defp git_env do
    [
      {"GIT_DIR", nil},
      {"GIT_WORK_TREE", nil},
      {"GIT_INDEX_FILE", nil},
      {"GIT_COMMON_DIR", nil},
      {"GIT_CONFIG_GLOBAL", "/dev/null"},
      {"GIT_CONFIG_NOSYSTEM", "1"}
    ]
  end
end
