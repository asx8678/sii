# 08 · Later and out of scope

## Later (not broken into tasks yet)

These are deliberately outside the 126 tasks. Each needs its own plan when the time comes.

| Item | Why later | Starting point |
|---|---|---|
| Writing to Fabric's mesh and controlling Fabric agents (steer/stop through Fabric's own control code in the adapter) | Read-only access (T10.05) covers observation; control needs Fabric's control protocol and acknowledgements | Fabric `src/topology/control-plane.ts`, `docs/agents.md` "Durable mesh coordination" |
| Fabric child agents for roles where evals show lift | Off by default in workers; needs eval evidence first | T10.04 (usage accounting), the boundary table |
| Advisors (performance, API design, …) | Only with measured lift | Eval harness ablations (T07.02) |
| Runners on other machines (second BEAM node, SSH) | Single machine first | `Si.Runner` behaviour (T03.04) |
| Pi's multi-session server (`pi-server`) | Experimental in Pi 0.87.1 | `packages/server/README.md` in the Pi repo |
| Native Elixir agent runner, native code mode | Pi and Fabric cover this | Si Fabric Design page |
| Memory search across sessions | Owner deferred it | — |
| Hot upgrades of a packaged release (`castle`, `jellyfish`) | Dev mode first | — |
| Upstream requests: a Fabric extension API for mesh and agent control; a Fovea fact cache keyed by content | Would remove adapter internals and cache seeding | Blueprint "Requests for upstream" |

## Skipped by the owner (do not implement)

Named only; they will be planned separately:

1. Self-healing and dev mode for Si itself.
2. The safety group: worker isolation profiles, command policy, prompt-injection handling, a data egress policy, dependency and secret checks, and keeping workers alive / reattaching them across Si restarts.

Where the plan touches these areas it does the minimum needed to operate and says so (for example, headless dialogs go to your inbox; the bridge listens on `127.0.0.1` with a token; sessions are restarted from their session files rather than kept alive across restarts).
