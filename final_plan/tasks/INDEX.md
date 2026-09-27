# Task index

126 tasks in 15 milestones. Tasks marked ★ are on the Astra path: the shortest route to `si review`, after which Astra reviews every later task.

Dependencies are listed per task; `tasks.yaml` has the same data in machine-readable form.

## M00 · Foundation

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T00.01](M00-foundation/T00.01-repository-and-phoenix-app-skeleton.md) ★ | Repository and Phoenix app skeleton | S | — |
| [T00.02](M00-foundation/T00.02-dependencies-lint-bin-ci-and-task-checks.md) ★ | Dependencies, lint, `bin/ci` and task checks | M | T00.01 |
| [T00.03](M00-foundation/T00.03-si-paths-and-si-home.md) ★ | `Si.Paths` and `$SI_HOME` | S | T00.02 |
| [T00.04](M00-foundation/T00.04-settings-loader-si-settings.md) ★ | Settings loader (`Si.Settings`) | M | T00.03 |
| [T00.05](M00-foundation/T00.05-sqlite-configuration-and-test-isolation.md) ★ | SQLite configuration and test isolation | S | T00.03 |
| [T00.06](M00-foundation/T00.06-ids-si-id.md) ★ | IDs (`Si.Id`) | S | T00.02 |
| [T00.07](M00-foundation/T00.07-event-log-si-events.md) ★ | Event log (`Si.Events`) | M | T00.05, T00.06 |
| [T00.08](M00-foundation/T00.08-tracing-helper-si-trace.md) | Tracing helper (`Si.Trace`) | S | T00.02, T00.04 |
| [T00.09](M00-foundation/T00.09-cli-transport-si-escript-and-si-cli-server.md) ★ | CLI transport: `si` escript and `Si.CLI.Server` | M | T00.03 |
| [T00.10](M00-foundation/T00.10-cockpit-shell-and-health.md) | Cockpit shell and `/health` | S | T00.01, T00.04 |
| [T00.11](M00-foundation/T00.11-test-support-helpers.md) ★ | Test support helpers | S | T00.03, T00.05 |
| [T00.12](M00-foundation/T00.12-cockpit-access-protection.md) | Cockpit access protection | S | T00.10, T00.09 |

## M01 · Git and repositories

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T01.01](M01-git-and-repositories/T01.01-si-git-command-wrapper-and-parsing.md) ★ | `Si.Git` command wrapper and parsing | M | T00.11 |
| [T01.02](M01-git-and-repositories/T01.02-repository-registry-and-si-repo-add-list-show.md) ★ | Repository registry and `si repo add/list/show` | M | T01.01, T00.07, T00.09 |
| [T01.03](M01-git-and-repositories/T01.03-repo-profile-schema-detection-and-si-repo-init.md) ★ | Repo profile: schema, detection and `si repo init` | M | T01.02, T00.04 |
| [T01.04](M01-git-and-repositories/T01.04-worktree-manager-with-copy-on-write-caches.md) ★ | Worktree manager with copy-on-write caches | M | T01.02 |
| [T01.05](M01-git-and-repositories/T01.05-freeze-snapshots-of-worktrees-and-refs.md) ★ | Freeze: snapshots of worktrees and refs | M | T01.04 |
| [T01.06](M01-git-and-repositories/T01.06-check-pool.md) ★ | Check pool | M | T01.04, T01.03, T01.05 |

## M02 · Checks

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T02.01](M02-checks/T02.01-check-command-runner.md) ★ | Check command runner | M | T01.06 |
| [T02.02](M02-checks/T02.02-diff-analysis-si-diff.md) ★ | Diff analysis (`Si.Diff`) | M | T01.01, T01.05 |
| [T02.03](M02-checks/T02.03-check-pipeline-results-and-si-check.md) ★ | Check pipeline, results and `si check` | M | T02.01, T02.02, T01.05 |
| [T02.04](M02-checks/T02.04-format-build-lint-and-tests-checks.md) ★ | Format, build, lint and tests checks | M | T02.03 |
| [T02.05](M02-checks/T02.05-test-integrity-check.md) ★ | Test-integrity check | M | T02.03 |
| [T02.06](M02-checks/T02.06-scope-check-and-glob-matching.md) | Scope check and glob matching | S | T02.03 |
| [T02.07](M02-checks/T02.07-diff-coverage-check-lcov.md) | Diff coverage check (LCOV) | M | T02.03, T02.04 |
| [T02.08](M02-checks/T02.08-mutation-check-stryker-report.md) | Mutation check (Stryker report) | M | T02.03, T02.04 |

## M03 · Pi sessions

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T03.01](M03-pi-sessions/T03.01-toolchain-manager.md) ★ | Toolchain manager | M | T00.04, T00.07, T00.09 |
| [T03.02](M03-pi-sessions/T03.02-profiles-pi-agent-directories-per-role.md) ★ | Profiles (Pi agent directories per role) | S | T03.01 |
| [T03.03](M03-pi-sessions/T03.03-scripted-provider-si-faux-and-si-test-faux.md) ★ | Scripted provider `si-faux` and `Si.Test.Faux` | M | T03.01 |
| [T03.04](M03-pi-sessions/T03.04-runner-behaviour-local-port-runner-and-os-process-helpers.md) ★ | Runner behaviour, local Port runner and OS process helpers | M | T00.03 |
| [T03.05](M03-pi-sessions/T03.05-pi-rpc-framing-and-command-correlation.md) ★ | Pi RPC framing and command correlation | M | T03.04 |
| [T03.06](M03-pi-sessions/T03.06-session-schema-and-controller-state-machine.md) ★ | Session schema and controller state machine | L | T03.05, T00.07 |
| [T03.07](M03-pi-sessions/T03.07-sessions-api-supervisor-and-si-session-cli.md) ★ | Sessions API, supervisor and `si session` CLI | M | T03.06, T03.02, T03.03, T00.09 |
| [T03.08](M03-pi-sessions/T03.08-cockpit-sessions-page.md) | Cockpit Sessions page | S | T03.07, T00.10 |

## M04 · Si bridge

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T04.01](M04-si-bridge/T04.01-bridge-protocol-schemas-and-validation.md) ★ | Bridge protocol schemas and validation | M | T00.02 |
| [T04.02](M04-si-bridge/T04.02-bridge-token-socket-and-session-channel.md) ★ | Bridge token, socket and session channel | M | T04.01, T03.07 |
| [T04.03](M04-si-bridge/T04.03-bridge-package-scaffold.md) ★ | Bridge package scaffold | S | T04.01, T03.07 |
| [T04.04](M04-si-bridge/T04.04-bridge-connection-join-and-status.md) ★ | Bridge connection, join and status | M | T04.03, T04.02 |
| [T04.05](M04-si-bridge/T04.05-event-forwarding-bridge-side.md) | Event forwarding (bridge side) | M | T04.04 |
| [T04.06](M04-si-bridge/T04.06-event-ingestion-and-analytics-tables.md) | Event ingestion and analytics tables | M | T04.05, T04.02 |
| [T04.07](M04-si-bridge/T04.07-si-tools.md) ★ | `si_*` tools | M | T04.04 |
| [T04.08](M04-si-bridge/T04.08-controls.md) | Controls | M | T04.04 |
| [T04.09](M04-si-bridge/T04.09-slot-gate.md) | Slot gate | M | T04.04, T04.05 |
| [T04.10](M04-si-bridge/T04.10-fabric-execution-trace-extraction.md) | Fabric execution trace extraction | S | T04.05 |
| [T04.11](M04-si-bridge/T04.11-contract-tests-and-overhead-measurement.md) | Contract tests and overhead measurement | M | T04.07, T04.08, T04.09, T04.05, T04.06 |
| [T04.12](M04-si-bridge/T04.12-opt-in-for-your-terminal-sessions.md) | Opt-in for your terminal sessions | S | T04.08 |

## M05 · Astra (first user-facing feature)

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T05.01](M05-astra/T05.01-model-families-and-diversity-rules.md) ★ | Model families and diversity rules | S | T00.04 |
| [T05.02](M05-astra/T05.02-verdicts-reviews-and-findings.md) ★ | Verdicts, reviews and findings | M | T04.01, T00.07, T01.05 |
| [T05.03](M05-astra/T05.03-astra-prompts-and-review-context.md) ★ | Astra prompts and review context | M | T05.02, T02.03 |
| [T05.04](M05-astra/T05.04-review-run-one-round.md) ★ | Review run (one round) | L | T05.03, T05.01, T04.07, T03.07, T01.04 |
| [T05.05](M05-astra/T05.05-si-review-cli.md) ★ | `si review` CLI | M | T05.04, T02.04 |
| [T05.06](M05-astra/T05.06-inbox-v1.md) ★ | Inbox v1 | M | T00.07, T00.09, T03.07 |
| [T05.07](M05-astra/T05.07-review-rounds-earlier-findings-and-escalation.md) ★ | Review rounds, earlier findings and escalation | M | T05.05, T05.06 |
| [T05.08](M05-astra/T05.08-astra-fix-mode.md) | Astra fix mode | L | T05.07, T04.08, T04.11 |
| [T05.09](M05-astra/T05.09-cockpit-reviews-and-inbox-pages.md) | Cockpit Reviews and Inbox pages | M | T05.07, T00.10 |
| [T05.10](M05-astra/T05.10-dogfooding-sis-own-profile-and-bin-task-review.md) ★ | Dogfooding: Si's own profile and `bin/task-review` | S | T05.07 |
| [T05.11](M05-astra/T05.11-first-run-setup-settings-writer-approval-policy-and-user-gui.md) | First-run setup, settings writer, approval policy and user guide | M | T05.05, T01.03 |
| [T05.12](M05-astra/T05.12-start-reviews-from-the-cockpit.md) | Start reviews from the cockpit | M | T05.09, T05.05, T00.12 |

## M06 · Tasks and the single-worker loop (quick tier)

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T06.01](M06-tasks-and-the-single-worker-loop/T06.01-task-board-and-state-machine.md) | Task board and state machine | M | T00.07, T01.02 |
| [T06.02](M06-tasks-and-the-single-worker-loop/T06.02-task-cli-and-cockpit-tasks-page.md) | Task CLI and cockpit Tasks page | S | T06.01, T00.09, T00.10 |
| [T06.03](M06-tasks-and-the-single-worker-loop/T06.03-si-task-si-report-and-si-ask-handlers.md) | `si_task`, `si_report` and `si_ask` handlers | M | T06.01, T04.07, T05.06 |
| [T06.04](M06-tasks-and-the-single-worker-loop/T06.04-dispatcher-one-worker.md) | Dispatcher (one worker) | L | T06.03, T03.07, T01.04, T05.11 |
| [T06.05](M06-tasks-and-the-single-worker-loop/T06.05-build-check-review-loop.md) | Build–check–review loop | L | T06.04, T05.07, T05.08 |
| [T06.06](M06-tasks-and-the-single-worker-loop/T06.06-merge-queue-v1.md) | Merge queue v1 | L | T06.05, T02.03 |
| [T06.07](M06-tasks-and-the-single-worker-loop/T06.07-delivery-to-a-branch-commit-trailers-and-cleanup.md) | Delivery to a branch, commit trailers and cleanup | M | T06.06 |
| [T06.08](M06-tasks-and-the-single-worker-loop/T06.08-run-ledger-v1.md) | Run ledger v1 | M | T06.05, T06.02 |
| [T06.09](M06-tasks-and-the-single-worker-loop/T06.09-tasks-and-session-actions-in-the-cockpit.md) | Tasks and session actions in the cockpit | M | T06.02, T04.08, T00.12, T03.08 |

## M07 · Eval harness and targets

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T07.01](M07-eval-harness-and-targets/T07.01-eval-task-format-and-si-eval-task-new.md) | Eval task format and `si eval task new` | M | T01.05, T01.03 |
| [T07.02](M07-eval-harness-and-targets/T07.02-arms-runner.md) | Arms runner | L | T07.01, T06.07 |
| [T07.03](M07-eval-harness-and-targets/T07.03-scoring-repeats-confidence-intervals-and-report.md) | Scoring, repeats, confidence intervals and report | M | T07.02 |
| [T07.04](M07-eval-harness-and-targets/T07.04-targets-and-seed-suite.md) | Targets and seed suite | M | T07.03 |

## M08 · Capacity: cost, budgets, scheduler, memory

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T08.01](M08-capacity-cost-budgets-scheduler-memory/T08.01-pricing-and-cost-per-model-call.md) | Pricing and cost per model call | S | T04.06 |
| [T08.02](M08-capacity-cost-budgets-scheduler-memory/T08.02-budgets.md) | Budgets | M | T08.01, T05.06, T05.04, T06.05, T08.03 |
| [T08.03](M08-capacity-cost-budgets-scheduler-memory/T08.03-scheduler-core.md) | Scheduler core | L | T08.01 |
| [T08.04](M08-capacity-cost-budgets-scheduler-memory/T08.04-admission-through-the-bridge-pause-and-freeze-all.md) | Admission through the bridge, pause and freeze-all | M | T08.03, T04.09, T08.02 |
| [T08.05](M08-capacity-cost-budgets-scheduler-memory/T08.05-memory-measurement-and-admission.md) | Memory measurement and admission | M | T03.07 |
| [T08.06](M08-capacity-cost-budgets-scheduler-memory/T08.06-warm-slots.md) | Warm slots | M | T08.05, T06.04 |
| [T08.07](M08-capacity-cost-budgets-scheduler-memory/T08.07-fallback-ladders-and-model-switch-between-turns.md) | Fallback ladders and model switch between turns | M | T08.03, T04.08, T05.01 |
| [T08.08](M08-capacity-cost-budgets-scheduler-memory/T08.08-parallel-workers.md) | Parallel workers | M | T08.04, T08.06 |
| [T08.09](M08-capacity-cost-budgets-scheduler-memory/T08.09-cache-discipline.md) | Cache discipline | M | T04.09, T08.01 |

## M09 · Workflows and planning

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T09.01](M09-workflows-and-planning/T09.01-workflow-schema-loader-templates-and-hashing.md) | Workflow schema, loader, templates and hashing | M | T00.04 |
| [T09.02](M09-workflows-and-planning/T09.02-workflow-validator-and-si-workflow-check.md) | Workflow validator and `si workflow check` | M | T09.01, T03.03, T05.01, T00.09 |
| [T09.03](M09-workflows-and-planning/T09.03-run-runtime-with-resume.md) | Run runtime with resume | L | T09.02, T06.05 |
| [T09.04](M09-workflows-and-planning/T09.04-lead-planning-session-and-si-plan.md) | Lead planning session and `si_plan` | L | T09.03, T04.07 |
| [T09.05](M09-workflows-and-planning/T09.05-plan-critique-gate-and-revisions.md) | Plan critique, gate and revisions | M | T09.04, T05.04 |
| [T09.06](M09-workflows-and-planning/T09.06-fan-out-sticky-workers-and-scope-requests.md) | Fan-out, sticky workers and scope requests | L | T09.04, T08.08, T02.06, T06.07 |
| [T09.07](M09-workflows-and-planning/T09.07-acceptance-review-and-fresh-final-reviewer.md) | Acceptance review and fresh final reviewer | M | T09.06, T05.07 |
| [T09.08](M09-workflows-and-planning/T09.08-intake-tiers-escalators-estimate-and-si-run.md) | Intake: tiers, escalators, estimate and `si run` | M | T09.03, T06.08 |
| [T09.09](M09-workflows-and-planning/T09.09-merge-queue-v2-batches-and-bisect.md) | Merge queue v2: batches and bisect | M | T06.06 |
| [T09.10](M09-workflows-and-planning/T09.10-delivery-targets-pull-request-patch-local-merge.md) | Delivery targets: pull request, patch, local merge | M | T06.07, T05.06 |
| [T09.11](M09-workflows-and-planning/T09.11-templates-review-only-and-fix-tests.md) | Templates review-only and fix-tests | M | T09.03, T05.07 |
| [T09.12](M09-workflows-and-planning/T09.12-start-runs-from-the-cockpit.md) | Start runs from the cockpit | S | T09.08, T06.09 |

## M10 · si-adapter and Fovea

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T10.01](M10-si-adapter-and-fovea/T10.01-adapter-scaffold-framing-and-supervisor.md) | Adapter scaffold, framing and supervisor | M | T03.01 |
| [T10.02](M10-si-adapter-and-fovea/T10.02-fovea-cache-seeding.md) | Fovea cache seeding | M | T10.01, T01.04 |
| [T10.03](M10-si-adapter-and-fovea/T10.03-fovea-impact-and-affected-tests.md) | Fovea impact and affected tests | M | T10.01, T02.04, T05.03, T10.02 |
| [T10.04](M10-si-adapter-and-fovea/T10.04-fabric-child-usage.md) | Fabric child usage | S | T10.01, T04.06 |
| [T10.05](M10-si-adapter-and-fovea/T10.05-fabric-mesh-reading-and-cockpit-panel.md) | Fabric mesh reading and cockpit panel | M | T10.01, T04.12 |

## M11 · Reliability

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T11.01](M11-reliability/T11.01-reconciler-framework.md) | Reconciler framework | M | T00.07 |
| [T11.02](M11-reliability/T11.02-sessions-reconciler.md) | Sessions reconciler | M | T11.01, T03.07 |
| [T11.03](M11-reliability/T11.03-worktrees-reconciler.md) | Worktrees reconciler | M | T11.01, T01.04 |
| [T11.04](M11-reliability/T11.04-check-pool-reconciler.md) | Check pool reconciler | S | T11.01, T01.06 |
| [T11.05](M11-reliability/T11.05-merge-queue-reconciler.md) | Merge queue reconciler | M | T11.01, T06.06 |
| [T11.06](M11-reliability/T11.06-runs-reconciler.md) | Runs reconciler | M | T11.01, T09.03 |
| [T11.07](M11-reliability/T11.07-fovea-cache-reconciler.md) | Fovea cache reconciler | S | T11.01, T10.02 |
| [T11.08](M11-reliability/T11.08-version-pinning-per-run-and-upgrade-check.md) | Version pinning per run and upgrade check | M | T04.11, T09.03, T05.11 |
| [T11.09](M11-reliability/T11.09-chaos-tests.md) | Chaos tests | M | T11.02, T11.03, T11.04, T11.05, T11.06 |
| [T11.10](M11-reliability/T11.10-backups.md) | Backups | S | T00.05, T00.09 |
| [T11.11](M11-reliability/T11.11-retention-and-si-gc.md) | Retention and `si gc` | M | T11.01, T06.07, T07.03 |
| [T11.12](M11-reliability/T11.12-release-build-background-service-and-path-install.md) | Release build, background service and PATH install | M | T00.09, T04.03, T11.10 |

## M12 · Signals, judgments and the Lead

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T12.01](M12-signals-judgments-and-the-lead/T12.01-deterministic-signals.md) | Deterministic signals | M | T04.06, T06.05, T08.09 |
| [T12.02](M12-signals-judgments-and-the-lead/T12.02-jev-client-and-foremans-questions.md) | Jev client and Foreman's questions | M | T12.01 |
| [T12.03](M12-signals-judgments-and-the-lead/T12.03-intervention-ladder.md) | Intervention ladder | M | T12.01, T04.08, T08.02 |
| [T12.04](M12-signals-judgments-and-the-lead/T12.04-lead-activations.md) | Lead activations | M | T12.03, T09.04, T06.08, T09.05, T08.04 |
| [T12.05](M12-signals-judgments-and-the-lead/T12.05-reviewer-canaries.md) | Reviewer canaries | M | T05.07 |
| [T12.06](M12-signals-judgments-and-the-lead/T12.06-disputes-and-arbitration.md) | Disputes and arbitration | M | T05.07, T06.03 |

## M13 · Models, routing and analytics

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T13.01](M13-models-routing-and-analytics/T13.01-model-catalog-capabilities-and-si-models.md) | Model catalog capabilities and `si models` | S | T05.01, T08.01 |
| [T13.02](M13-models-routing-and-analytics/T13.02-scoreboard.md) | Scoreboard | M | T13.01, T12.05 |
| [T13.03](M13-models-routing-and-analytics/T13.03-router-with-exploration-and-diversity.md) | Router with exploration and diversity | M | T13.02, T08.07 |
| [T13.04](M13-models-routing-and-analytics/T13.04-orchestration-only-mode-for-weak-code-mode-models.md) | Orchestration-only mode for weak code-mode models | S | T13.02, T03.02 |
| [T13.05](M13-models-routing-and-analytics/T13.05-analytics-page.md) | Analytics page | M | T04.06, T08.01, T06.08 |
| [T13.06](M13-models-routing-and-analytics/T13.06-opentelemetry-traces-per-run.md) | OpenTelemetry traces per run | M | T00.08, T09.03 |
| [T13.07](M13-models-routing-and-analytics/T13.07-livebook-notebook.md) | Livebook notebook | S | T13.05, T13.02 |

## M14 · Learning loop

| ID | Task | Size | Depends on |
|---|---|---|---|
| [T14.01](M14-learning-loop/T14.01-failure-capture-and-fingerprints.md) | Failure capture and fingerprints | M | T04.10, T05.02 |
| [T14.02](M14-learning-loop/T14.02-lesson-extraction.md) | Lesson extraction | M | T14.01 |
| [T14.03](M14-learning-loop/T14.03-promotion-delivery-and-retirement-of-lessons.md) | Promotion, delivery and retirement of lessons | M | T14.02, T03.02, T00.10 |
| [T14.04](M14-learning-loop/T14.04-versioned-prompts-and-eval-gating.md) | Versioned prompts and eval gating | M | T07.03 |
