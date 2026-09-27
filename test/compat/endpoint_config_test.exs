defmodule BootstrapCompatibility.EndpointConfigTest do
  use ExUnit.Case, async: false

  setup do
    previous = for name <- ["PORT", "PHX_SERVER"], do: {name, System.get_env(name)}
    for {name, _} <- previous, do: System.delete_env(name)

    on_exit(fn ->
      for {name, value} <- previous do
        if value, do: System.put_env(name, value), else: System.delete_env(name)
      end
    end)

    :ok
  end

  test "unset PORT preserves configured development and test ports" do
    assert endpoint(:dev)[:http] == [ip: {127, 0, 0, 1}, port: 4040]
    assert endpoint(:test)[:http] == [ip: {127, 0, 0, 1}, port: 4002]
    assert endpoint(:test)[:server] == false
  end

  test "explicit PORT overrides both ports without enabling the test server" do
    System.put_env("PORT", "4567")
    assert endpoint(:dev)[:http] == [ip: {127, 0, 0, 1}, port: 4567]
    assert endpoint(:test)[:http] == [ip: {127, 0, 0, 1}, port: 4567]
    assert endpoint(:test)[:server] == false
  end

  defp endpoint(environment) do
    base = Config.Reader.read!("config/config.exs", env: environment)
    runtime = Config.Reader.read!("config/runtime.exs", env: environment)

    base
    |> Config.Reader.merge(runtime)
    |> Keyword.fetch!(:si)
    |> Keyword.fetch!(SiWeb.Endpoint)
  end
end
