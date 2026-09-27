# Bootstrap dependency compatibility

## T00.01 bootstrap compatibility

These fixes are limited to the owner-approved T00.01 amendment. Native Mix dependency fetching and compilation remain in use; no Postgrex or other functional dependency is added.

## Pins and provenance

| Dependency | Pin | Reason |
| --- | --- | --- |
| DNSCluster | Hex `0.3.0`, exact requirement and `mix.lock` checksums | Removes the redundant refined-type comparison from `warn_on_invalid_dist/0`. |
| PhoenixEcto | `phoenixframework/phoenix_ecto` commit `a0c342b5a57581037974cc992a23f4f89a77b29f` | Replaces deprecated `xref: [exclude: ...]` with the current compiler API, retaining the same pre-existing exclusion set. |
| LiveDashboard | Hex `0.9.1`, exact requirement and `mix.lock` checksums | Migrates its deprecated compiler API; the single patch below handles genuinely optional formatter modules. |

LiveDashboard upstream HEAD `83a0bd137ed3e4c66b8037b140a2744803a48e13` was reviewed and **not used**: it adds `Postgrex.Interval` to `@compile :no_warn_undefined`. Our patch adds no warning suppression. Existing upstream exclusion sets are not extended.

Upstream sources:

- https://repo.hex.pm/tarballs/dns_cluster-0.3.0.tar
- https://github.com/phoenixframework/phoenix_ecto/tree/a0c342b5a57581037974cc992a23f4f89a77b29f
- https://repo.hex.pm/tarballs/phoenix_live_dashboard-0.9.1.tar

## One bounded source transformation

`live_dashboard.exs` accepts only the exact upstream or exact patched bytes of `lib/phoenix/live_dashboard/pages/ecto_stats_page.ex`:

- Original SHA256: `c7a8997ca63f9e671cc25b639f95dc4afc1cff58b6a669101772d2548fbd5b4a`
- Patched SHA256: `c7c4763ebb3663bd679b8e5cb613e168ada68a29733ccd9edbe4d862bda6586b`

It replaces the generic struct-union call with typed clauses emitted only for installed modules. Decimal, Duration and an installed Postgrex interval retain direct `to_string/1` calls; unavailable modules have no emitted call. The byte/percent/other-value fallbacks remain unchanged. No runtime rescue, dynamic-call workaround, compiler exclusion or log filtering hides a defect.

The root `deps.get` and `deps.update` aliases run the native fetch task, then this helper, **before compilation**. An actual transformation runs the supported `mix deps.clean phoenix_live_dashboard --build` operation to invalidate old compiled artifacts across environments while preserving source. Already-patched bytes are a no-op. Missing or unexpected source fails visibly without writing it. A cold `mix setup` follows the same `deps.get` alias; no `mix run` bootstraps the patch.

`test/fixtures/live_dashboard/ecto_stats_page.ex.fixture` is the exact 10 KB upstream source, solely for regression tests, with its upstream MIT license alongside it. Tests invoke the actual helper and compile its actual output to cover absent/available optional modules, existing formatter behavior, idempotence and mismatch rejection. No complete package is vendored.

When an upstream release implements genuine optional-module handling without adding suppressions, vet it on the pinned Elixir/OTP, remove this helper/aliases/fixture, and keep cold compilation and behavior regression coverage.

## Tailwind packaging (owner-directed repair)

The official standalone macOS ARM artifacts inspected during bootstrap failed `codesign --verify`; none is executed or modified by setup. Instead, the existing Tailwind Elixir wrapper's documented `:path` integration uses project-local npm packages. `assets/package.json` pins only build devDependencies `tailwindcss` and `@tailwindcss/cli` to the generated version **4.3.0**. The complete npm lock records official registry tarball URLs and SHA512 integrity for transitive platform packages. Wrapper version validation remains enabled.

Official CLI provenance: https://registry.npmjs.org/@tailwindcss/cli/-/cli-4.3.0.tgz; integrity `sha512-X9kdlqyMopO9fewbgHsEeuy31YzMHbdZ9VsKt004tB+mxSg1CNbyhZYCzvhciN0AM4R4b5lvIprPjtNq7iQxpQ==`. `mix assets.setup` uses native `npm ci` with cache under `tmp/npm-cache`, followed by the unchanged esbuild installation. No global installation or application dependency is added.

Node resolves the generated DaisyUI CommonJS bundle as an object containing `default`, which the npm CLI rejects as an options plugin. The CSS therefore names the **existing same-version `.mjs` bundles** from the generated Mix DaisyUI dependency explicitly. Plugin options, themes, CSS rules and generated tests are unchanged; no DaisyUI npm dependency is added.

npm 11.19 requires explicit install-script review. The lock's `@parcel/watcher@2.6.0` script (`scripts/build-from-source.js`) runs node-gyp only when `npm_config_build_from_source=true`; ordinarily its platform package supplies the native watcher. Its version-scoped `allowScripts` entry permits the reviewed script rather than disabling scripts or hiding npm's warning. No blanket script approval or warning suppression is used.

`test/compat/tailwind_config_test.exs` guards exact version/lock agreement, local executable version, enabled wrapper validation, setup/build/deploy/watch entrypoints and both ESM options-plugin exports. Cold setup and watcher/deploy probes remain required whenever this integration changes.

## T00.02: ten OTP 29 / Elixir 1.20 sites

`otp29.exs` implements only the owner-approved ten sites in nine release files.
The native `deps.get` / `deps.update` aliases call it before compilation, then run
the unchanged LiveDashboard helper. Yamerl is required. Entirely absent PropEr /
PropCheck packages are allowed (test-only fetches may exclude them); any present
package must contain all expected files. Every file in a package is verified
before the first write. Exact patched bytes are a no-op; unknown bytes or missing
files raise. A real transformation invokes native `deps.clean <app> --build` only
when cross-environment build artifacts exist, preserving fetched source. No
compiler directives, diagnostic filters, overrides, or additional dependencies
are used. All eleven direct task constraints remain unchanged.

### Official provenance

The nine fixture files were compared byte-for-byte against independently fetched
official Hex archives, not merely copied from a modified dependency directory:

| Archive URL | Archive SHA256 |
| --- | --- |
| https://repo.hex.pm/tarballs/yamerl-0.10.0.tar | `346adb2963f1051dc837a2364e4acf6eb7d80097c0f53cbdc3046ec8ec4b4e6e` |
| https://repo.hex.pm/tarballs/proper-1.5.0.tar | `fbf7cf0625e5441a314514f7d8e1eaff52090fcd94ff34b5171ff293d3f9969a` |
| https://repo.hex.pm/tarballs/propcheck-1.5.0.tar | `3388aa7909277faed166dfced39fad6ecae3c3be064352d37646be459fc80e09` |

| File (relative to package) | Original SHA256 | Patched SHA256 |
| --- | --- | --- |
| yamerl `src/yamerl_node_binary.erl` | `8bc3b969e4d8311160828409415216b1737d1108a6869df57f422c5ffa7fb744` | `f54989d359b57006e479ffa9095b91b21ea81d346f38d3c591eb404b85cc3ba9` |
| yamerl `src/yamerl_constr.erl` | `72e65f7d5b365e0467a58f62ebb7ed080d2b8834aecb94844a9f6c5f9ce6af30` | `29d03c9b28235997babb16528a3862b9178d62685aae345f54df5bc5f1339c3e` |
| proper `src/proper_statem.erl` | `d3ea9db5c68e6210559ea403809edb94465b68a5ef94d2c11ad4515949104944` | `4868fcd6efabf4d87e1e83336a537f6ea042f0aef6d7d96b27f3235f0077ae1d` |
| proper `src/proper_erlang_abstract_code.erl` | `a4624f61c445ad86ad2bfe23f2c6e027352e09040ef2fd87e0b4509177d95d0e` | `a53dce02210353878c52bf70f1e7276099482c01e045a9dbc3e367c0f68f0a99` |
| propcheck `lib/counterstrike.ex` | `1ca1df55eefe32cc70c8282f528ae40ce64f5c45017c7170debc31fdf460019e` | `39fb2b84563fe355ea87253dc0f81f760ba32067edd01f0e44280f4caa239c08` |
| propcheck `lib/properties.ex` | `0ef9e59d706234960b168564d69726fe616c3483cb8c3a3be4b4f48321077ad3` | `5bbbf32d513248e93c14fedd98cf367e9ce80c9a953fa8474d8221b45c729b55` |
| propcheck `lib/statem.ex` | `3b1ba4a16388e5387f5fe655d95987b6b090a82309b1406a959c4f86e7fdf5b5` | `7effe566ceff3d08215e4e09623337856b194d94cf16c50374d11edb860a332b` |
| propcheck `lib/statem/model_dsl.ex` | `59be3c04c0f1e5e518fa8b781f80659360979af0fa336315da1aea7330b0142d` | `849e5d2a630b1eadf7c98fc3d62ccb7189514d6528726eb52a383bab5475b555` |
| propcheck `lib/result.ex` | `26b940f35c8c3ee6b33b4f4e34a45e2cb7155a5e895c58e913b6fd93b355451b` | `b289eb362149c047a957d9c67f851fddd4848eaf151eee7e5c754b206a22d195` |

### Semantic review and regressions

- Both binary decoding expressions retain the original surrounding `case` and
  exact legacy catch values: success unchanged, throw value unchanged, exit as
  `{'EXIT', Reason}`, error as `{'EXIT', {Reason, Stack}}`. Thus invalid base64
  still raises the original parsing exception in ordinary and detailed modes.
- Optional `Mod:module_info()` remains an autoload attempt. Its return value was
  discarded; the replacement discards exceptions before the same export check.
- PropEr's parallel worker retains `{WorkerPid, Payload}` messaging to its parent, including
  raw thrown values and legacy exit/error tuples. No change to `await/1` or its
  error handling is made. Tests compile the actual affected private functions
  from the installed BEAM, require zero compiler warnings, and test each class.
- The local record-description predicate and its one call are renamed together;
  validation of `{RecordName, [FieldAtoms]}` is not replaced by OTP's record BIF.
- Exactly four unused `require` statements are removed. Actual property macros,
  both sized state-machine generators, and isolated counterexample persistence
  remain covered. Result matches its existing struct contract before updates;
  test/current/error accumulation, status, stop, and unknown-message failure
  remain unchanged.

Original upstream behavior was probed before patching; tests assert those
ordinary/detailed/invalid YAML results, optional-module errors, parallel message
shapes, record-option acceptance/rejection, and result transitions. Lifecycle
coverage verifies all nine output hashes, idempotence including modification
time, package-wide pre-write mismatch rejection, cold no-artifact paths,
optional test-only absence, malformed existing packages, and native stale-build
cleanup. All pre-existing bootstrap assertions remain unchanged.

Only the nine affected source files (about 244 KB total) are fixtures, not full
packages. PropCheck fixtures use `.ex.fixture` to preserve upstream bytes under
formatting. Upstream licenses accompany Yamerl and PropCheck. PropEr files retain
their GPL-3.0-or-later notices; its Hex archive omits the license text, so
`proper/COPYING` is the GPL v3 text from https://www.gnu.org/licenses/gpl-3.0.txt
(SHA256 `3972dc9744f6499f0f9b2dbf76696f2ae7ad8af9b23dde66d6af86c9dfb36986`).

The task's specified `config :opentelemetry, traces_exporter: :none` avoids
attempting to load an exporter dependency that this task does not include. It
does not suppress logs or disable the SDK, and no collector/network is needed.
Replace repairs only after vetting a compatible release implementing equivalent
behavior without suppressions; retain behavior and cold-build regressions.
