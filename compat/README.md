# T00.01 bootstrap compatibility

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
