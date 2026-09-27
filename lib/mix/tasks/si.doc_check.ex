defmodule Mix.Tasks.Si.DocCheck do
  @moduledoc "Checks compiled documentation and specs for modules defined in the given source files."
  use Mix.Task

  @shortdoc "Check module, function and macro documentation and specs"

  @doc "Compiles if needed, checks FILE arguments, and exits 2 for usage or 1 for missing documentation."
  @spec run([String.t()]) :: :ok | no_return()
  @impl true
  def run([]) do
    Mix.shell().error("usage: mix si.doc_check FILE...")
    exit({:shutdown, 2})
  end

  def run(files) do
    Mix.Task.run("compile")

    results =
      files
      |> Enum.flat_map(fn file ->
        file |> File.read!() |> Code.string_to_quoted!() |> modules(nil)
      end)
      |> Enum.uniq_by(&elem(&1, 0))
      |> Enum.map(&check_module/1)

    {module_count, function_count, problems} =
      Enum.reduce(results, {0, 0, []}, fn {mods, funcs, errors}, {m, f, acc} ->
        {m + mods, f + funcs, acc ++ errors}
      end)

    if problems == [] do
      Mix.shell().info("ok: #{module_count} modules, #{function_count} functions")
      :ok
    else
      Enum.each(problems, fn problem -> Mix.shell().error(problem) end)
      exit({:shutdown, 1})
    end
  end

  defp modules({:defmodule, _, [{:__aliases__, _, parts}, [do: body]]}, parent) do
    module = module_name(parts, parent)
    [{module, implementations(body)} | modules(body, module)]
  end

  defp modules({:defmodule, _, [module, [do: body]]}, _parent) when is_atom(module) do
    [{module, implementations(body)} | modules(body, module)]
  end

  defp modules({:defmodule, _, _}, _parent),
    do: Mix.raise("cannot resolve dynamic defmodule name")

  defp modules({_form, _meta, args}, parent) when is_list(args), do: modules(args, parent)
  defp modules({key, value}, parent) when is_atom(key), do: modules(value, parent)
  defp modules(list, parent) when is_list(list), do: Enum.flat_map(list, &modules(&1, parent))
  defp modules(_ast, _parent), do: []

  defp module_name([:"Elixir" | parts], _parent), do: Module.concat(parts)
  defp module_name(parts, nil), do: Module.concat(parts)
  defp module_name(parts, parent), do: Module.concat([parent | parts])

  defp implementations(body) do
    expressions =
      case body do
        {:__block__, _, expressions} -> expressions
        expression -> [expression]
      end

    {_, implementations} = Enum.reduce(expressions, {false, MapSet.new()}, &implementation/2)
    implementations
  end

  defp implementation({:@, _, [{:impl, _, [value]}]}, {_pending, found}),
    do: {value == true, found}

  defp implementation({kind, _, [head | _]}, {pending, found}) when kind in [:def, :defmacro] do
    key = function_key(head)
    {false, if(pending, do: MapSet.put(found, key), else: found)}
  end

  defp implementation(_expression, state), do: state
  defp function_key({:when, _, [head | _]}), do: function_key(head)
  defp function_key({name, _, args}), do: {name, length(args || [])}

  defp check_module({module, implementations}) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, :hidden, _, _} ->
        Mix.shell().info("note: #{inspect(module)}: @moduledoc false (skipped)")
        {0, 0, []}

      {:docs_v1, _, _, _, module_doc, _, docs} ->
        errors = if module_doc == :none, do: ["#{inspect(module)}: missing @moduledoc"], else: []
        specs = specs(module)
        functions = Enum.filter(docs, &checked_function?(&1, implementations))

        {1, length(functions),
         errors ++ Enum.flat_map(functions, &function_errors(&1, module, specs))}

      {:error, reason} ->
        {0, 0, ["#{inspect(module)}: cannot fetch documentation (#{inspect(reason)})"]}
    end
  end

  defp specs(module) do
    case Code.Typespec.fetch_specs(module) do
      {:ok, specs} ->
        MapSet.new(specs, fn {{name, arity}, _} -> {Atom.to_string(name), arity} end)

      :error ->
        MapSet.new()
    end
  end

  defp checked_function?({{kind, name, arity}, _, _, doc, _}, implementations) do
    kind in [:function, :macro] and doc != :hidden and
      not MapSet.member?(implementations, {name, arity})
  end

  defp function_errors({{kind, name, arity}, _, _, doc, _}, module, specs) do
    label = "#{inspect(module)}.#{name}/#{arity}"
    doc_errors = if doc == :none, do: ["#{label}: missing @doc"], else: []
    # Macro specs use the compiled MACRO- name and an extra caller argument.
    spec_key =
      if kind == :macro, do: {"MACRO-#{name}", arity + 1}, else: {Atom.to_string(name), arity}

    spec_errors = if MapSet.member?(specs, spec_key), do: [], else: ["#{label}: missing @spec"]
    doc_errors ++ spec_errors
  end
end
