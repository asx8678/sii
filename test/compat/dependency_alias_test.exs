defmodule BootstrapCompatibility.DependencyAliasTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @moduletag :tmp_dir
  @fixture Path.expand("../fixtures/live_dashboard/ecto_stats_page.ex.fixture", __DIR__)

  setup %{tmp_dir: dir} do
    callback = Mix.Project.config()[:aliases][:"deps.get"] |> List.last()
    update_callback = Mix.Project.config()[:aliases][:"deps.update"] |> List.last()
    assert callback == update_callback

    File.write!(Path.join(dir, "mix.exs"), """
    defmodule BootstrapAliasFixture.MixProject do
      use Mix.Project
      def project, do: [app: :bootstrap_alias_fixture, version: "0.0.0", deps: []]
    end
    """)

    source =
      Path.join(
        dir,
        "deps/phoenix_live_dashboard/lib/phoenix/live_dashboard/pages/ecto_stats_page.ex"
      )

    File.mkdir_p!(Path.dirname(source))
    File.cp!(@fixture, source)
    %{dir: dir, callback: callback, source: source}
  end

  test "cold fetch patches without attempting cleanup of nonexistent builds", context do
    log = run_callback(context)
    refute log =~ "warning:"
    refute log =~ "Cleaning"
    assert BootstrapCompatibility.LiveDashboard.apply_file!(context.source) == :unchanged
  end

  test "changed source invalidates stale builds across environments and repeated fetch is a no-op",
       context do
    builds =
      for env <- ["dev", "test"],
          do: Path.join(context.dir, "_build/#{env}/lib/phoenix_live_dashboard")

    for build <- builds do
      File.mkdir_p!(build)
      File.write!(Path.join(build, "stale.beam"), "stale fixture")
    end

    log = run_callback(context)
    assert log =~ "Cleaning phoenix_live_dashboard"
    refute log =~ "warning:"
    for build <- builds, do: refute(File.exists?(build))
    assert File.exists?(context.source)

    [build | _] = builds
    File.mkdir_p!(build)
    marker = Path.join(build, "new.beam")
    File.write!(marker, "new fixture")
    assert run_callback(context) == ""
    assert File.read!(marker) == "new fixture"
  end

  defp run_callback(context) do
    capture_io(fn ->
      stderr =
        capture_io(:stderr, fn ->
          Mix.Project.in_project(:bootstrap_alias_fixture, context.dir, fn _ ->
            context.callback.([])
          end)
        end)

      IO.write(stderr)
    end)
  end
end
