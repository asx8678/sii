Code.require_file("compat/live_dashboard.exs", __DIR__)
Code.require_file("compat/otp29.exs", __DIR__)

defmodule Si.MixProject do
  use Mix.Project

  def project do
    [
      app: :si,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      # These are compiler input data exercised by si_doc_check_test, not test modules.
      test_ignore_filters: [
        "test/fixtures/doc_check/documented.ex",
        "test/fixtures/doc_check/undocumented.ex"
      ],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Si.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.13"},
      {:phoenix_ecto,
       github: "phoenixframework/phoenix_ecto", ref: "a0c342b5a57581037974cc992a23f4f89a77b29f"},
      {:ecto_sql, "~> 3.13"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "== 0.9.1"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:daisyui,
       github: "saadeghi/daisyui",
       tag: "v5.5.20",
       sparse: "packages/bundle",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "== 0.3.0"},
      {:bandit, "~> 1.5"},
      {:yaml_elixir, "~> 2.12"},
      {:jsv, "~> 0.25.0"},
      {:muontrap, "~> 2.0"},
      {:req, "~> 0.7.4"},
      {:opentelemetry_api, "~> 1.5"},
      {:opentelemetry, "~> 1.7"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},
      {:propcheck, "~> 1.5", only: :test},
      {:stream_data, "~> 1.4", only: :test},
      {:mox, "~> 1.3", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "deps.get": ["deps.get", &patch_otp29/1, &patch_live_dashboard/1],
      "deps.update": ["deps.update", &patch_otp29/1, &patch_live_dashboard/1],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": [
        "cmd --cd assets npm ci --cache ../tmp/npm-cache",
        "esbuild.install --if-missing"
      ],
      "assets.build": ["compile", "tailwind si", "esbuild si"],
      "assets.deploy": [
        "tailwind si --minify",
        "esbuild si --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end

  defp patch_otp29(_args) do
    deps = Mix.Project.deps_path()

    for app <- [:yamerl, :proper, :propcheck],
        app == :yamerl or File.exists?(Path.join(deps, Atom.to_string(app))) do
      case BootstrapCompatibility.OTP29.apply_package!(deps, app) do
        :patched ->
          builds = Path.join(Path.dirname(Mix.Project.build_path()), "*/lib/#{app}")

          if Path.wildcard(builds) != [] do
            Mix.Task.reenable("deps.clean")
            Mix.Task.run("deps.clean", [Atom.to_string(app), "--build"])
          end

        :unchanged ->
          :ok
      end
    end
  end

  defp patch_live_dashboard(_args) do
    path =
      Path.join([
        Mix.Project.deps_path(),
        "phoenix_live_dashboard/lib/phoenix/live_dashboard/pages/ecto_stats_page.ex"
      ])

    case BootstrapCompatibility.LiveDashboard.apply_file!(path) do
      :patched ->
        # Match deps.clean's cross-environment search. A cold fetch has no BEAMs to discard.
        builds = Path.join(Path.dirname(Mix.Project.build_path()), "*/lib/phoenix_live_dashboard")

        if Path.wildcard(builds) != [] do
          Mix.Task.reenable("deps.clean")
          Mix.Task.run("deps.clean", ["phoenix_live_dashboard", "--build"])
        end

      :unchanged ->
        :ok
    end
  end
end
