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
        file
        |> File.read!()
        |> Code.string_to_quoted!()
        |> modules()
        |> Enum.map(fn {module, implementations} ->
          {module, implementations, Path.expand(file)}
        end)
      end)
      |> Enum.uniq_by(&{elem(&1, 0), elem(&1, 2)})
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

  defp modules(ast) do
    # Alias-only compiler APIs never expand or execute arbitrary user macros.
    env = %{__ENV__ | module: nil, function: nil, aliases: [], lexical_tracker: nil, tracers: []}
    {found, _env} = walk(ast, env)
    found
  end

  defp walk({:__block__, _, expressions}, env) do
    Enum.reduce(expressions, {[], env}, fn expression, {found, scope} ->
      {modules, scope} = walk(expression, scope)
      {found ++ modules, scope}
    end)
  end

  defp walk({:alias, meta, [target | rest]}, env) do
    opts = alias_options(List.first(rest) || [])
    scope = Enum.reduce(alias_targets(target, env), env, &define_alias(&2, meta, &1, opts))
    {[], scope}
  end

  defp walk({:defmodule, _, [name, [do: body]]}, env) do
    {module, scope} = module_definition(name, env)
    {children, _child_scope} = walk(body, %{scope | module: module})
    {[{module, implementations(body)} | children], scope}
  end

  defp walk({_form, _meta, args}, env) when is_list(args), do: walk_scopes(args, env)
  defp walk({_key, value}, env), do: walk(value, env)
  defp walk(list, env) when is_list(list), do: walk_scopes(list, env)
  defp walk(_ast, env), do: {[], env}

  defp walk_scopes(expressions, env) do
    # Aliases in sibling keyword blocks or function bodies cannot escape their scope.
    {Enum.flat_map(expressions, fn expression -> elem(walk(expression, env), 0) end), env}
  end

  defp module_definition({:__aliases__, _, [:"Elixir" | _]} = name, env),
    do: {resolve_module(name, env), env}

  defp module_definition({:__aliases__, meta, [head | tail]}, %{module: parent} = env)
       when is_atom(head) and not is_nil(parent) do
    # Kernel.defmodule nests literal alias segments and introduces the first
    # segment as an alias in the enclosing module (not at file scope).
    prefix = Module.concat(parent, head)
    scope = define_alias(env, meta, prefix, as: Module.concat([head]))
    {Module.concat([prefix | tail]), scope}
  end

  defp module_definition(name, env), do: {resolve_module(name, env), env}

  defp resolve_module({:__aliases__, meta, parts}, env) do
    case parts do
      [{:__MODULE__, _, _} | rest] when not is_nil(env.module) ->
        Module.concat([env.module | rest])

      _ ->
        resolve_alias(parts, meta, env)
    end
  end

  defp resolve_module({:__MODULE__, _, _}, %{module: module}) when not is_nil(module), do: module
  defp resolve_module(module, _env) when is_atom(module), do: module
  defp resolve_module(_expression, _env), do: Mix.raise("cannot resolve dynamic module name")

  defp resolve_alias(parts, meta, env) do
    if not Enum.all?(parts, &is_atom/1), do: Mix.raise("cannot resolve dynamic module alias")

    case Macro.Env.expand_alias(env, meta, parts) do
      {:alias, module} -> module
      :error -> Module.concat(parts)
    end
  end

  defp alias_targets({{:., _, [prefix, :{}]}, _, suffixes}, env) do
    prefix = resolve_module(prefix, env)
    Enum.map(suffixes, fn {:__aliases__, _, parts} -> Module.concat([prefix | parts]) end)
  end

  defp alias_targets(target, env), do: [resolve_module(target, env)]

  defp alias_options(opts) do
    Enum.map(opts, fn
      {:as, {:__aliases__, _, parts}} -> {:as, Module.concat(parts)}
      {key, value} when key in [:as, :warn] and is_atom(value) -> {key, value}
      _ -> Mix.raise("cannot resolve dynamic alias options")
    end)
  end

  defp define_alias(env, meta, module, opts) do
    case Macro.Env.define_alias(env, meta, module, opts) do
      {:ok, scope} -> scope
      {:error, message} -> Mix.raise(message)
    end
  end

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

  defp check_module({module, implementations, source}) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, _, metadata, _} = docs ->
        if metadata_source(metadata) == source do
          check_docs(module, implementations, docs)
        else
          {0, 0, ["#{inspect(module)}: compiled documentation does not belong to #{source}"]}
        end

      error ->
        check_docs(module, implementations, error)
    end
  end

  defp metadata_source(%{source_path: path}), do: path |> to_string() |> Path.expand()
  defp metadata_source(_metadata), do: nil

  defp check_docs(module, implementations, docs) do
    case docs do
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
