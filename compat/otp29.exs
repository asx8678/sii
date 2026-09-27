defmodule BootstrapCompatibility.OTP29 do
  @moduledoc """
  Applies the ten reviewed Yamerl 0.10.0, PropEr 1.5.0 and PropCheck 1.5.0 repairs.

  Every affected file must match its exact original or patched SHA256 before any
  file in that package is written. See `compat/README.md` for source provenance.
  """

  @binary_catch "try base64:decode(Text)\n         catch\n             throw:Value -> Value;\n             exit:Reason -> {'EXIT', Reason};\n             error:Reason:Stack -> {'EXIT', {Reason, Stack}}\n         end"
  @worker_catch "try {ok,F(X)}\n        catch\n            throw:Value -> Value;\n            exit:Reason -> {'EXIT', Reason};\n            error:Reason:Stack -> {'EXIT', {Reason, Stack}}\n        end"
  @repairs [
    {:yamerl, "src/yamerl_node_binary.erl",
     "8bc3b969e4d8311160828409415216b1737d1108a6869df57f422c5ffa7fb744",
     "f54989d359b57006e479ffa9095b91b21ea81d346f38d3c591eb404b85cc3ba9",
     [{"case catch base64:decode(Text) of", "case (" <> @binary_catch <> ") of"}]},
    {:yamerl, "src/yamerl_constr.erl",
     "72e65f7d5b365e0467a58f62ebb7ed080d2b8834aecb94844a9f6c5f9ce6af30",
     "29d03c9b28235997babb16528a3862b9178d62685aae345f54df5bc5f1339c3e",
     [{"    catch Mod:module_info(),", "    try Mod:module_info() catch _:_ -> ok end,"}]},
    {:proper, "src/proper_statem.erl",
     "d3ea9db5c68e6210559ea403809edb94465b68a5ef94d2c11ad4515949104944",
     "4868fcd6efabf4d87e1e83336a537f6ea042f0aef6d7d96b27f3235f0077ae1d",
     [{"catch {ok,F(X)}", @worker_catch}]},
    {:proper, "src/proper_erlang_abstract_code.erl",
     "a4624f61c445ad86ad2bfe23f2c6e027352e09040ef2fd87e0b4509177d95d0e",
     "a53dce02210353878c52bf70f1e7276099482c01e045a9dbc3e367c0f68f0a99",
     [
       {"fun(R) -> is_record(R) end", "fun(R) -> is_record_description(R) end"},
       {"is_record({R, Fs}) when is_atom(R) ->",
        "is_record_description({R, Fs}) when is_atom(R) ->"}
     ]},
    {:propcheck, "lib/counterstrike.ex",
     "1ca1df55eefe32cc70c8282f528ae40ce64f5c45017c7170debc31fdf460019e",
     "39fb2b84563fe355ea87253dc0f81f760ba32067edd01f0e44280f4caa239c08",
     [{"  require Logger\n", ""}]},
    {:propcheck, "lib/properties.ex",
     "0ef9e59d706234960b168564d69726fe616c3483cb8c3a3be4b4f48321077ad3",
     "5bbbf32d513248e93c14fedd98cf367e9ce80c9a953fa8474d8221b45c729b55",
     [{"  require Logger\n", ""}]},
    {:propcheck, "lib/statem.ex",
     "3b1ba4a16388e5387f5fe655d95987b6b090a82309b1406a959c4f86e7fdf5b5",
     "7effe566ceff3d08215e4e09623337856b194d94cf16c50374d11edb860a332b",
     [{"    require PropCheck.BasicTypes\n", ""}]},
    {:propcheck, "lib/statem/model_dsl.ex",
     "59be3c04c0f1e5e518fa8b781f80659360979af0fa336315da1aea7330b0142d",
     "849e5d2a630b1eadf7c98fc3d62ccb7189514d6528726eb52a383bab5475b555",
     [{"    require PropCheck.BasicTypes\n", ""}]},
    {:propcheck, "lib/result.ex",
     "26b940f35c8c3ee6b33b4f4e34a45e2cb7155a5e895c58e913b6fd93b355451b",
     "b289eb362149c047a957d9c67f851fddd4848eaf151eee7e5c754b206a22d195",
     [
       {"def handle_call({:message, fmt, args}, _from, state) do",
        "def handle_call({:message, fmt, args}, _from, %__MODULE__{} = state) do"}
     ]}
  ]

  @doc "Verifies and patches one supported package; missing or unknown source raises."
  @spec apply_package!(Path.t(), :yamerl | :proper | :propcheck) :: :patched | :unchanged
  def apply_package!(deps, app) when app in [:yamerl, :proper, :propcheck] do
    changes =
      for {^app, relative, original_hash, patched_hash, edits} <- @repairs do
        path = Path.join([deps, Atom.to_string(app), relative])
        source = File.read!(path)

        case sha256(source) do
          ^patched_hash ->
            nil

          ^original_hash ->
            patched =
              Enum.reduce(edits, source, fn {old, new}, text -> String.replace(text, old, new) end)

            if sha256(patched) != patched_hash do
              raise ArgumentError, "#{app} compatibility patch output hash mismatch: #{path}"
            end

            {path, patched}

          _ ->
            raise ArgumentError, "unexpected #{app} release source hash: #{path}"
        end
      end

    case Enum.reject(changes, &is_nil/1) do
      [] ->
        :unchanged

      writes ->
        Enum.each(writes, fn {path, source} -> File.write!(path, source) end)
        :patched
    end
  end

  defp sha256(source), do: :crypto.hash(:sha256, source) |> Base.encode16(case: :lower)
end
