defmodule BootstrapCompatibility.TailwindConfigTest do
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)

  test "official build-only packages and integrity lock agree with enabled wrapper version" do
    manifest = json("assets/package.json")
    lock = json("assets/package-lock.json")
    version = Application.fetch_env!(:tailwind, :version)

    assert version == "4.3.0"
    assert manifest["private"] == true
    refute Map.has_key?(manifest, "dependencies")

    assert manifest["devDependencies"] == %{
             "@tailwindcss/cli" => version,
             "tailwindcss" => version
           }

    assert lock["packages"][""]["devDependencies"] == manifest["devDependencies"]
    assert Application.get_env(:tailwind, :version_check, true) == true

    for package <- ["tailwindcss", "@tailwindcss/cli"] do
      entry = lock["packages"]["node_modules/#{package}"]
      assert entry["version"] == version
      assert entry["dev"] == true
      assert String.starts_with?(entry["resolved"], "https://registry.npmjs.org/")
      assert String.starts_with?(entry["integrity"], "sha512-")
    end
  end

  test "configured local executable reports the exact expected version" do
    path = Application.fetch_env!(:tailwind, :path)
    assert path == Path.join(@root, "assets/node_modules/.bin/tailwindcss")
    assert Tailwind.bin_path() == path
    assert Tailwind.bin_version() == {:ok, "4.3.0"}
  end

  test "native setup installs lockfile before build and retains build deploy and watcher entrypoints" do
    aliases = Mix.Project.config()[:aliases]
    assert aliases[:setup] == ["deps.get", "ecto.setup", "assets.setup", "assets.build"]

    assert aliases[:"assets.setup"] == [
             "cmd --cd assets npm ci --cache ../tmp/npm-cache",
             "esbuild.install --if-missing"
           ]

    assert aliases[:"assets.build"] == ["compile", "tailwind si", "esbuild si"]

    assert aliases[:"assets.deploy"] == [
             "tailwind si --minify",
             "esbuild si --minify",
             "phx.digest"
           ]

    config = Config.Reader.read!(Path.join(@root, "config/config.exs"), env: :dev)

    assert config[:si][SiWeb.Endpoint][:watchers][:tailwind] ==
             {Tailwind, :install_and_run, [:si, ~w(--watch)]}
  end

  test "generated DaisyUI options use existing ESM bundles under Node" do
    css = File.read!(Path.join(@root, "assets/css/app.css"))
    assert css =~ ~s(@plugin "daisyui/packages/bundle/daisyui.mjs")
    assert css =~ ~s(@plugin "daisyui/packages/bundle/daisyui-theme.mjs")

    for name <- ["daisyui", "daisyui-theme"] do
      path = Path.join(Mix.Project.deps_path(), "daisyui/packages/bundle/#{name}.mjs")

      script =
        "import plugin from #{Jason.encode!(path)}; if (!plugin.__isOptionsFunction) process.exit(1)"

      assert {"", 0} =
               System.cmd("node", ["--input-type=module", "-e", script], stderr_to_stdout: true)
    end
  end

  defp json(path), do: @root |> Path.join(path) |> File.read!() |> Jason.decode!()
end
