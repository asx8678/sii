defmodule BootstrapCompatibility.YamerlTest do
  use ExUnit.Case, async: false

  test "ordinary and detailed binary nodes retain decoded data and presentation" do
    assert :yamerl_constr.string(~c"!!binary SGVsbG8=") == ["Hello"]

    assert :yamerl_constr.string(~c"!!binary SGVsbG8=", detailed_constr: true) ==
             [
               {:yamerl_doc,
                {:yamerl_binary, :yamerl_node_binary, ~c"tag:yaml.org,2002:binary",
                 [line: 1, column: 10], "Hello"}}
             ]
  end

  test "invalid base64 retains the exact parsing exception in both modes" do
    expected =
      {:yamerl_exception,
       [
         {:yamerl_parsing_error, :error, ~c"Invalid binary/Not base64", 1, 10, :not_a_binary,
          {:yamerl_scalar, 1, 10, {:yamerl_tag, 1, 1, ~c"tag:yaml.org,2002:binary"}, :flow,
           :plain, ~c"%%%"}, []}
       ]}

    for opts <- [[], [detailed_constr: true]] do
      assert catch_throw(:yamerl_constr.string(~c"!!binary %%%", opts)) == expected
    end
  end

  test "optional binary module is loaded and missing module still raises the original option error" do
    :code.purge(:yamerl_node_binary)
    :code.delete(:yamerl_node_binary)
    assert :code.is_loaded(:yamerl_node_binary) == false

    assert :yamerl_constr.string(~c"!!binary SGVsbG8=", node_mods: [:yamerl_node_binary]) ==
             ["Hello"]

    assert {:file, _} = :code.is_loaded(:yamerl_node_binary)

    assert catch_throw(:yamerl_constr.string(~c"plain", node_mods: [:missing_compat_node])) ==
             {:yamerl_exception,
              [
                {:yamerl_invalid_option, :error,
                 ~c"Invalid value for option \"node_mods\": it must be a list of modules",
                 {:node_mods, [:missing_compat_node]}}
              ]}
  end
end
