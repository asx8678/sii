defmodule BootstrapCompatibility.PropertyDependenciesTest do
  use ExUnit.Case, async: false
  use PropCheck

  import ExUnit.CaptureIO
  alias BootstrapCompatibility.OTP29

  @moduletag :tmp_dir
  @moduletag store_counter_example: false
  @fixtures Path.expand("../fixtures", __DIR__)
  @hashes %{
    "yamerl/src/yamerl_node_binary.erl" =>
      "f54989d359b57006e479ffa9095b91b21ea81d346f38d3c591eb404b85cc3ba9",
    "yamerl/src/yamerl_constr.erl" =>
      "29d03c9b28235997babb16528a3862b9178d62685aae345f54df5bc5f1339c3e",
    "proper/src/proper_statem.erl" =>
      "4868fcd6efabf4d87e1e83336a537f6ea042f0aef6d7d96b27f3235f0077ae1d",
    "proper/src/proper_erlang_abstract_code.erl" =>
      "a53dce02210353878c52bf70f1e7276099482c01e045a9dbc3e367c0f68f0a99",
    "propcheck/lib/counterstrike.ex" =>
      "39fb2b84563fe355ea87253dc0f81f760ba32067edd01f0e44280f4caa239c08",
    "propcheck/lib/properties.ex" =>
      "5bbbf32d513248e93c14fedd98cf367e9ce80c9a953fa8474d8221b45c729b55",
    "propcheck/lib/statem.ex" =>
      "7effe566ceff3d08215e4e09623337856b194d94cf16c50374d11edb860a332b",
    "propcheck/lib/statem/model_dsl.ex" =>
      "849e5d2a630b1eadf7c98fc3d62ccb7189514d6528726eb52a383bab5475b555",
    "propcheck/lib/result.ex" =>
      "b289eb362149c047a957d9c67f851fddd4848eaf151eee7e5c754b206a22d195"
  }

  setup %{tmp_dir: dir} do
    deps = Path.join(dir, "deps")
    File.mkdir_p!(deps)

    for app <- [:yamerl, :proper, :propcheck] do
      fixture = if app == :yamerl, do: "yamerl", else: "property_dependencies/#{app}"
      File.cp_r!(Path.join(@fixtures, fixture), Path.join(deps, "#{app}"))
    end

    for path <- Path.wildcard(Path.join(deps, "**/*.fixture")) do
      File.rename!(path, String.trim_trailing(path, ".fixture"))
    end

    File.write!(Path.join(dir, "mix.exs"), """
    defmodule OTP29Fixture.MixProject do
      use Mix.Project
      def project, do: [app: :otp29_fixture, version: "0.0.0", deps: []]
    end
    """)

    callback = Enum.at(Mix.Project.config()[:aliases][:"deps.get"], 1)
    assert is_function(callback, 1)
    assert callback == Enum.at(Mix.Project.config()[:aliases][:"deps.update"], 1)
    %{dir: dir, deps: deps, callback: callback}
  end

  for app <- [:yamerl, :proper, :propcheck] do
    @tag app: app
    test "#{app}: exact release hashes and idempotence", %{deps: deps, app: app} do
      assert OTP29.apply_package!(deps, app) == :patched

      for {relative, hash} <- @hashes, String.starts_with?(relative, "#{app}/") do
        path = Path.join(deps, relative)
        source = File.read!(path)
        assert sha256(source) == hash
        File.touch!(path, 1_000_000_000)
        before = File.stat!(path)
        assert OTP29.apply_package!(deps, app) == :unchanged
        assert File.stat!(path).mtime == before.mtime
        assert File.read!(path) == source
      end
    end

    @tag app: app
    test "#{app}: unexpected source is rejected before any package writes", %{
      deps: deps,
      app: app
    } do
      paths =
        for {relative, _} <- @hashes,
            String.starts_with?(relative, "#{app}/"),
            do: Path.join(deps, relative)

      path = List.last(Enum.sort(paths))
      File.write!(path, File.read!(path) <> "\n% unexpected source\n")
      before = Map.new(paths, &{&1, File.read!(&1)})

      assert_raise ArgumentError, ~r/unexpected .* release source hash/, fn ->
        OTP29.apply_package!(deps, app)
      end

      assert Map.new(paths, &{&1, File.read!(&1)}) == before
    end

    @tag app: app
    test "#{app}: native callback cleans stale builds, not sources, and preserves fresh builds on repeat",
         context do
      builds =
        for env <- ["dev", "test"], do: Path.join(context.dir, "_build/#{env}/lib/#{context.app}")

      for build <- builds do
        File.mkdir_p!(build)
        File.write!(Path.join(build, "stale.beam"), "stale")
      end

      log = run_callback(context)
      assert log =~ "Cleaning #{context.app}"
      refute log =~ "warning"
      for build <- builds, do: refute(File.exists?(build))
      assert OTP29.apply_package!(context.deps, context.app) == :unchanged
      [build | _] = builds
      File.mkdir_p!(build)
      marker = Path.join(build, "fresh.beam")
      File.write!(marker, "fresh")
      assert run_callback(context) == ""
      assert File.read!(marker) == "fresh"
    end
  end

  test "native cold callback patches all packages without cleanup warnings", context do
    assert run_callback(context) == ""

    for app <- [:yamerl, :proper, :propcheck] do
      assert OTP29.apply_package!(context.deps, app) == :unchanged
    end

    refute File.exists?(Path.join(context.dir, "_build"))
    assert Application.fetch_env!(:opentelemetry, :traces_exporter) == :none
  end

  test "native cold callback needs no artifacts and optional test-only packages may be absent",
       context do
    File.rm_rf!(Path.join(context.deps, "proper"))
    File.rm_rf!(Path.join(context.deps, "propcheck"))
    assert run_callback(context) == ""
    assert OTP29.apply_package!(context.deps, :yamerl) == :unchanged
    refute File.exists?(Path.join(context.dir, "_build"))
  end

  test "an existing incomplete optional package is not silently skipped", context do
    File.rm!(Path.join(context.deps, "propcheck/lib/result.ex"))
    assert_raise File.Error, fn -> run_callback(context) end
  end

  test "actual parallel worker code preserves every catch class and parent message shape" do
    mod = compile_worker!()

    for {fun, expected} <- [
          {fn _ -> :value end, {:ok, :value}},
          {fn _ -> throw(:thrown) end, :thrown},
          {fn _ -> throw({:ok, :thrown_value}) end, {:ok, :thrown_value}},
          {fn _ -> exit(:stopped) end, {:EXIT, :stopped}}
        ] do
      [pid] = apply(mod, :spawn_jobs, [fun, [:arg]])
      assert_receive {^pid, ^expected}
    end

    [pid] = apply(mod, :spawn_jobs, [fn _ -> :erlang.error(:badarg) end, [:arg]])
    assert_receive {^pid, {:EXIT, {:badarg, stack}}}
    assert [{__MODULE__, _, 1, _} | _] = stack
    assert Enum.any?(stack, fn {module, _, _, _} -> module == mod end)
    assert apply(mod, :pmap, [fn x -> x * 2 end, [1, 2, 3]]) == [2, 4, 6]

    assert catch_error(apply(mod, :pmap, [fn _ -> exit(:stopped) end, [:arg]])) ==
             {:EXIT, :stopped}
  end

  test "record descriptions still validate local atom field lists rather than the new BIF" do
    for records <- [[], [thing: [:field]], [empty: []]] do
      assert :proper_types.is_type(:proper_erlang_abstract_code.expr(records: records))
    end

    for records <- [[thing: [42]], [{42, [:field]}], [:bad], :not_a_list] do
      assert catch_error(:proper_erlang_abstract_code.expr(records: records)) == :badarg
    end
  end

  property "Properties macro still expands and executes real generated values",
           [:quiet, numtests: 10] do
    forall value <- integer() do
      is_integer(value)
    end
  end

  test "both state-machine sized macros retain generator behavior" do
    for module <- [PropCheck.StateM, PropCheck.StateM.ModelDSL] do
      generator = module.more_commands(3, PropCheck.BasicTypes.exactly(:value))
      assert :proper_gen.pick(generator) == {:ok, :value}
    end
  end

  test "CounterStrike still stores and reloads counterexamples in an isolated file", %{dir: dir} do
    file = Path.join(dir, "counterexamples.dets")

    child = %{
      id: :compat_counterstrike,
      start: {PropCheck.CounterStrike, :start_link, [file, []]}
    }

    pid = start_supervised!(child)
    mfa = {__MODULE__, :example, 0}
    assert PropCheck.CounterStrike.counter_example(pid, mfa) == :none
    assert PropCheck.CounterStrike.add_counter_example(pid, mfa, [42]) == :ok
    assert stop_supervised(:compat_counterstrike) == :ok
    pid = start_supervised!(child)
    assert PropCheck.CounterStrike.counter_example(pid, mfa) == {:ok, [42]}
    assert PropCheck.CounterStrike.counter_example(pid, {__MODULE__, :other, 0}) == :others
  end

  test "Result maintains tests, current test, failures, errors, status and stop transitions" do
    {:ok, initial} = PropCheck.Result.init([])
    assert initial == %PropCheck.Result{}

    {:reply, :ok, state} =
      PropCheck.Result.handle_call({:message, ~c"Testing", [:sample]}, nil, initial)

    {:reply, :ok, state} = PropCheck.Result.handle_call({:message, ~c"Failed", [42]}, nil, state)
    {:reply, :ok, state} = PropCheck.Result.handle_call({:message, ~c"Error", [:bad]}, nil, state)
    assert state.current == [:sample]
    expected = {[[:sample]], [{[:sample], {~c"Error", [:bad]}}, {[:sample], {~c"Failed", [42]}}]}
    assert PropCheck.Result.handle_call(:status, nil, state) == {:reply, expected, state}
    assert PropCheck.Result.handle_call(:stop, nil, state) == {:stop, :normal, :ok, state}

    assert_raise CondClauseError, fn ->
      PropCheck.Result.handle_call({:message, ~c"Unknown", []}, nil, state)
    end
  end

  defp compile_worker! do
    # Compile the actual affected private functions from the installed BEAM, not a replica.
    {:ok, {:proper_statem, [abstract_code: {:raw_abstract_v1, forms}]}} =
      :beam_lib.chunks(:code.which(:proper_statem), [:abstract_code])

    functions =
      Enum.filter(forms, fn
        {:function, _, name, _, _} -> name in [:pmap, :spawn_jobs, :await, :spawn_link_cp]
        _ -> false
      end)

    mod = :compat_property_worker

    forms = [
      {:attribute, 1, :module, mod},
      {:attribute, 1, :export, [spawn_jobs: 2, pmap: 2]} | functions
    ]

    assert {:ok, ^mod, beam, []} = :compile.forms(forms, [:return_errors, :return_warnings])
    assert {:module, ^mod} = :code.load_binary(mod, ~c"compat_property_worker", beam)

    on_exit(fn ->
      :code.purge(mod)
      :code.delete(mod)
    end)

    mod
  end

  defp run_callback(context) do
    capture_io(fn ->
      stderr =
        capture_io(:stderr, fn ->
          Mix.Project.in_project(:otp29_fixture, context.dir, fn _ -> context.callback.([]) end)
        end)

      IO.write(stderr)
    end)
  end

  defp sha256(source), do: :crypto.hash(:sha256, source) |> Base.encode16(case: :lower)
end
