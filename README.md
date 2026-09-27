# Si

## Local setup

Use Elixir `1.20.4-otp-29` and Erlang/OTP `29.1` (`.tool-versions`), plus Node.js 24 or newer and npm (validated with Node 24.21.0/npm 11.19.0). No global JavaScript packages are needed.

From a clean checkout:

```sh
mix setup
mix phx.server
```

Visit http://127.0.0.1:4040/. `PORT` can explicitly override the configured port.

`mix setup` fetches locked Mix dependencies, applies the reviewed bootstrap compatibility patch, creates/migrates the generated SQLite database, runs `npm ci` in `assets/`, and builds CSS/JS. npm uses the project-local ignored `tmp/npm-cache`. Commit `assets/package-lock.json` with any intentional build dependency update. Build dependencies must be installed even for production asset compilation (do not omit npm devDependencies).

```sh
mix assets.setup   # locked local npm CLI plus esbuild
mix assets.build   # CSS and JS
MIX_ENV=prod mix compile --warnings-as-errors # emits production colocated assets first
MIX_ENV=prod mix assets.deploy
mix test
```

The Tailwind wrapper uses the integrity-locked official npm CLI at `assets/node_modules/.bin/tailwindcss`, with its version check enabled. The generated development watcher and production deployment still use the wrapper. No rejected standalone binary, signature bypass or local re-signing is used. See [bootstrap compatibility notes](compat/README.md) for exact pins and provenance.

Phoenix deployment guidance: https://phoenix.hexdocs.pm/deployment.html.
