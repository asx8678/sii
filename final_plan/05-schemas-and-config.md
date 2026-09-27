# 05 · Schemas and configuration

All schemas are JSON Schema (draft 2020-12) files under `protocol/`, validated in Elixir with `jsv` and mirrored in TypeScript with TypeBox. YAML files are parsed with `yaml_elixir` and then validated as JSON.

## 1. Settings: `$SI_HOME/config.yml`

Defaults live in `priv/default_config.yml`; your file is deep-merged over them (maps merge, lists replace). Schema: `protocol/config.schema.json`.

```yaml
node:
  name: si                           # distributed node short name
http:
  ip: 127.0.0.1
  port: 4040
toolchain:
  pi: "0.87.1"
  fabric: "0.97.0"
  fovea: "0.31.1"
  sources:                            # "npm:<package>" (default; all three are on npm) or "path:<dir>" (packed with npm pack)
    pi: "npm:@earendil-works/pi-coding-agent"
    fabric: "npm:pi-fabric"
    fovea: "npm:pi-fovea"
models:                               # provider/model as Pi names them
  astra:   {model: "openai/gpt-5", thinking: high}
  builder: {model: "vllm/qwen3-coder", thinking: medium}
  lead:    {model: "openai/gpt-5", thinking: high}
  critic:  {model: "openrouter/kimi-k2", thinking: medium}
  arbiter: {model: "openrouter/deepseek-v3", thinking: medium}
  judge:   {provider: jev, model: null}   # jev | local; local uses models.judge_local
review:
  fix_policy: auto                    # writer | astra | auto
  max_rounds: {quick: 3, standard: 5, full: 5}
  canary_rate: 0.05
  verdict_timeout_s: 900
  diversity: family                   # family | model
workers:
  max: 1                              # raised in M08 by memory measurement
checks:
  pool_size: 2
  timeouts_s: {format: 120, build: 600, lint: 300, tests: 900, test_all: 1800, coverage: 1200, mutation: 2400}
  thresholds: {diff_coverage: 80, mutation: 60}
  stop_at_first_failure: true
bridge:
  slot_timeout_ms: 2000
  batch_ms: 100
  max_batch: 50
scheduler:                            # from M08
  pools: []                           # [{id, kind: provider|gpu, match: {provider, models?}, concurrency, tokens_per_min?, gpu_rate_usd_per_s?}]
budgets:                              # from M08
  run_default_usd: 6.0
  supervision_share: 0.15
  warn_at: 0.8
memory:
  budget_mb: 16000
notifications:
  desktop: true
```

Keys added by later tasks (each task adds its keys to `priv/default_config.yml` and `protocol/config.schema.json`): `models.astra.alternatives`, `models.critic.alternatives` (T05.01, T09.05), `review.keep_astra_s` (T05.07), `budgets.task_default_usd` (T08.02), `budgets.ask_above_usd`, `tiers.limits` (T09.08), `scheduler.default_concurrency` (T08.03), `scheduler.fallback_after_s`, `models.ladders` (T08.07), `workers.max_cap` (T08.05), `workers.warm_slots` (T08.06), `workers.sticky_keep_s` (T09.06), `merge_queue.batch_size` (T09.09), `evals.targets`, `evals.auto_resolve_s` (T07.02, T07.04), `judgments.every_turns`, `models.judge.local_model` (T12.02), `router.exploration` (T13.03), `models.orchestration_only_above`, `models.code_mode_again_below` (T13.04), `telemetry.otlp_endpoint` (T13.06), `backups.at`, `backups.keep` (T11.10), `reconcilers.enabled` (T11.01), `models.lessons` (T14.02), `review.max_cost_usd` (T05.04), `tasks.max_cost_usd` (T06.05), `profiles.builder.approvals` (T03.02; **no default**, you set it with `si init`, T05.11), `sessions.max_file_mb` (T03.06), `evidence.max_file_mb` (T01.05), `cache.retention`, `cache.affinity` (T08.09), `cockpit.require_token` (T00.12), `retention.*` (T11.11).

`Si.Settings.get(path)` takes a list path, e.g. `Si.Settings.get([:review, :fix_policy])`, and returns the merged value (atoms for keys are created only from the schema's known keys; unknown keys in your file are rejected at load time with a clear error).

## 2. Repo profile: `<repo>/.si/repo.yml`

Schema: `protocol/repo_profile.schema.json`.

```yaml
language: typescript                  # typescript | elixir | other
commands:                             # each optional; a missing command makes its check "skipped"
  format:   npm run format:check
  build:    npm run typecheck
  lint:     npm run lint -- {files}
  test:     npx vitest run {tests}
  test_all: npm test
  coverage: npx vitest run --coverage --coverage.reporter=lcov {tests}
  mutation: npx stryker run --incremental --mutate {files}
coverage:
  lcov_path: coverage/lcov.info       # where the coverage command writes LCOV
mutation:
  report_path: reports/mutation/mutation.json   # Stryker JSON report
tests:
  patterns: ["test/**/*.test.ts", "src/**/*.test.ts"]   # used to find test files and affected tests
risky_paths: ["src/protocol.ts", "migrations/**"]
parallel:
  env: {}                             # extra env per slot; {slot} and {port} placeholders allowed
  ports: {start: 4100, per_slot: 10}
pi:
  trust_project: false                # true → sessions start with --approve instead of --no-approve
```

Also `worktree: {submodules: auto, lfs: auto}` (T01.04): run `git submodule update --init --recursive` and `git lfs pull` in new worktrees when the repository uses them.

Also `test_integrity: {exempt: [...]}` (T02.05): path prefixes (a trailing `/` means a directory) that the test-integrity check skips, for files that contain its tokens on purpose. Default `[]`.

Placeholders in commands: `{files}` (changed files, shell-escaped, space-separated), `{tests}` (test files to run), `{lcov}`, `{slot}`, `{port}`. If a placeholder expands to an empty list, the command runs without it (e.g. whole suite) unless `commands.<name>_requires_files: true`.

Elixir defaults written by detection: `format: mix format --check-formatted`, `build: mix compile --warnings-as-errors`, `lint: mix credo --strict {files}`, `test: mix test {tests}`, `test_all: mix test`, `coverage: mix test --cover {tests}` with `lcov_ex` configured, `parallel.env: {MIX_TEST_PARTITION: "{slot}"}`.

## 3. Tool payloads (`protocol/tools/*.schema.json`)

### `si_task` → result
```json
{"task_id": "tsk_…", "attempt": 2, "round": 1, "title": "...", "goal": "...",
 "acceptance": ["..."], "scope": ["src/auth/**"], "test_paths": ["test/auth"],
 "commands": {"test": "npx vitest run {tests}", "build": "npm run typecheck"},
 "feedback": "Findings or check failures from the previous round, or null"}
```

### `si_report` args
```json
{"status": "done", "summary": "What changed and why (≤ 2000 chars)",
 "tests_run": ["npx vitest run test/auth/refresh.test.ts"], "blocked_reason": null}
```
`status`: `done` | `blocked`. `blocked_reason` required when blocked.

### `si_ask` args → result
Args `{"question": "...", "context": "..."}`; result `{"answer": "..." | null, "pending": true | false, "inbox_item_id": "inb_…" | null}`.

### `si_scope` args → result
Args `{"files": ["src/auth/token_store.ts"], "reason": "..."}`; result `{"decision": "approved" | "refused" | "pending", "note": "..."}`.

### `si_verdict` args
```json
{
  "verdict": "revise",
  "summary": "One blocking issue: expiry edge case untested.",
  "findings": [
    {"severity": "blocking", "file": "src/session.ts", "line": 42,
     "category": "missing_test",
     "problem": "A session that expires exactly now is treated as valid.",
     "evidence": {"kind": "input", "detail": "expires_at = now returns valid=true"},
     "suggested_fix": "Use >= in the comparison and add a test for equality."}
  ],
  "previous": [{"finding_id": "fnd_…", "fixed": true, "note": null}]
}
```
- `verdict`: `approve` | `revise`. `approve` with any `blocking` finding is invalid.
- `category`: `correctness`, `missing_test`, `test_quality`, `error_handling`, `concurrency`, `performance`, `api_contract`, `convention`, `readability`, `scope`, `other`.
- `evidence.kind`: `failing_test`, `reproduction`, `rule`, `input`. A blocking finding without `evidence` is stored as a note with `downgraded: true`.
- `previous`: required from round 2; one entry per open finding of earlier rounds.

### `si_plan` args (Lead)
```json
{"acceptance": ["..."],
 "steps": [{"id": "s1", "title": "...", "description": "...", "depends_on": [],
            "files": ["src/auth/**"], "test_paths": ["test/auth"], "criteria": [0, 1]}]}
```

### `si_dispute` args
`{"finding_id": "fnd_…", "argument": "...", "evidence": {"kind": "...", "detail": "..."}}`.

## 4. Workflows (M09)

Schema `protocol/workflow.schema.json`. Built-in templates in `priv/workflows/`. A workflow either is a template or `extends` one; merging: maps deep-merge, lists replace, `null` removes a key. Full field reference is in task T09.01. Example (override of `standard`):

```yaml
extends: standard
name: feature-auth
inputs: {goal: {type: string}}
repo_profile: .si/repo.yml
roles:
  builder:
    profile: writer
    route: {prefer: [vllm/qwen3-coder, openrouter/kimi-k2]}
    fabric: {agents: {maxDepth: 0}, mesh: {enabled: false}}
    fovea: on
  astra:
    profile: reviewer
    route: {differ_from: builder, family: other, prefer: [openai/gpt-5]}
    fovea: impact_only
steps:
  build:
    order: depends_on
    sticky: true
    checks: [format, build, lint, tests, diff_coverage, mutation, test_integrity, scope]
    review: {by: astra, until: approved, max_rounds: 5, fix: auto}
  deliver:
    target: branch
budget: {total: "$6", supervision_share: 0.15}
```

## 5. Prompts

Stored as Markdown under `priv/prompts/<role>/<name>.md` with a front-matter `version: <int>`. `Si.Prompts.load(role, name)` returns `%{text, version, hash}`. The hash is recorded on every review/attempt that used it. Initial prompts:

| File | Used by | Task |
|---|---|---|
| `astra/review.md` | Astra review rounds | T05.02 |
| `astra/fix.md` | Astra fix mode | T05.07 |
| `builder/task.md` | builder first message | T06.04 |
| `builder/feedback.md` | follow-up after failed checks or revise | T06.05 |
| `lead/plan.md`, `lead/decide.md` | Lead | T09.04, T12.04 |
| `critic/plan_review.md` | plan critique | T09.05 |
| `arbiter/dispute.md` | disputes | T12.06 |

## 6. Model families

`priv/models.yml` maps `provider/model` patterns to a family and default prices:

```yaml
- match: "openai/gpt-*"        # glob on "provider/model"
  family: openai-gpt
- match: "openai-codex/gpt-*"  # ChatGPT subscription through Pi
  family: openai-gpt
- match: "xai/grok-*"
  family: xai-grok
- match: "openrouter/kimi-*"
  family: moonshot-kimi
- match: "zro/kimi-*"
  family: moonshot-kimi
- match: "zro/glm-*"
  family: zhipu-glm
- match: "coralbricks/glm-*"
  family: zhipu-glm
- match: "openrouter/deepseek-*"
  family: deepseek
- match: "zro/deepseek-*"
  family: deepseek
- match: "coralbricks/deepseek-*"
  family: deepseek
- match: "stepfun/step-*"
  family: stepfun
- match: "vllm/qwen*"
  family: qwen
- match: "*"                   # everything else, including routers such as zro/auto
  family: unknown
```

The owner's providers (checked with `pi --list-models` on 27 September 2026) are covered. Routers such as `zro/auto` stay `unknown` on purpose: they can answer with any family, so they never count as a different family.

Diversity levels: `other_family` (families differ and neither is `unknown`), `same_family` (same family, different model), `same_model_fresh` (same model, different session; allowed only when nothing else is configured, and flagged).
