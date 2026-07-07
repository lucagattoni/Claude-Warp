# Reference — ClaudeWarp vs Native Claude Code

A side-by-side: for each ClaudeWarp skill, the closest **native** Claude Code feature, and
specifically what the skill adds beyond it. Read this if you're deciding whether you need
ClaudeWarp at all, or which of its skills earn their place in a given project.

> **The short version.** Every scaffolder routes to the native feature first and stops when it's
> enough — ClaudeWarp only earns its ceremony where native stops short: **durability across
> sessions/crashes/machines**, **unattended headless operation with no open session**, **hard
> budget/scope caps**, and **a self-pruning mechanism** that retires ClaudeWarp's own components
> once Claude Code absorbs them. See [Concepts](../concepts.md) for the plan/shape model this
> table assumes, and [Architecture → Native vs harness](architecture.md#native-vs-harness) for the
> mechanical, component-level version of this same boundary (what `/claude-warp-sync` tracks).

---

## Execution shapes

| ClaudeWarp skill | Closest native feature | What ClaudeWarp adds |
|---|---|---|
| `/claude-warp-new-goal` | [`/goal`](https://code.claude.com/docs/en/goal) — per-turn Stop-hook evaluator on an independent small model | A `GOAL.md` **state file** that survives context resets, a **G0–G3 readiness gate** before anything runs, hard `--max-turns`/`--max-budget-usd` **caps** (`/goal` has none), and a logged **cron/CI runner**. The generated runner *delegates* its until-done loop to native `/goal` rather than reimplementing it — this is genuinely additive, not a rebuild. |
| `/claude-warp-new-loop` | [`/loop`](https://code.claude.com/docs/en/scheduled-tasks) / `.claude/loop.md` | Works with **no open session at all**: a duplicate-run **guard**, structured **cross-run state** with dedup, a daemon-free **crontab/launchd trigger**, and **L1/L2/L3 autonomy gating** (mandatory checker + stagnation guard at L3). Native `/loop` needs a session open or backgrounded and expires after 7 days. |
| `/claude-warp-new-harness` | [`/batch`](https://code.claude.com/docs/en/commands) (independent-unit fan-out with a PR per unit) and [dynamic workflows](https://code.claude.com/docs/en/workflows) (scripted orchestration, up to 1,000 agents) | **Cross-session durability** — a workflow's state lives in the runtime and restarts fresh if the session exits mid-run; `features.json` + git-based recovery survive a crash, a reboot, or a different machine resuming the queue. Plus **dependency-wave scheduling** (`depends_on`/`wave`, built into the schema — a `/batch` unit must be independent), a **mandatory QA evaluator with corroboration** at R2+, and a **headless `--retry` re-entry point** for work spanning many days. |
| `/claude-warp-contract` | [`/plan`](https://code.claude.com/docs/en/permission-modes#analyze-before-you-edit-with-plan-mode) (plan mode), [Ultraplan](https://code.claude.com/docs/en/ultraplan) | A plan that must **execute unattended**, not just be approved and then watched: R0–R5 **risk classification**, a machine-readable `contract.yaml` another run can consume via `--contract`, explicit `stop.check`/`verifier`/`budget` fields, a **worth-it gate** for fuzzy/greenfield asks, and a critical pass with a **red-team charter + honesty riders** (anti-fabrication, confidence-capped-by-verified-ratio, an "Unverified" set) so the review of the plan can't become verifier theater itself. |

## Supporting infrastructure

| ClaudeWarp skill / component | Closest native feature | What ClaudeWarp adds |
|---|---|---|
| `/claude-warp-new-hook` | Native [command / prompt / agent hooks](https://code.claude.com/docs/en/hooks-guide) | Ten **named, pre-built patterns** (`verify-before-stop`, `destructive-block`, `review-gate`, `intent-gate`, `kill-switch`, …) instead of writing hook JSON and a script from scratch each time. Routes to a native **prompt-based** Stop hook first when the check is judgment rather than a real command — the scripted pattern stays for deterministic exit codes and exact, zero-cost matching. |
| `external-trigger` (harness component) | [Routines](https://code.claude.com/docs/en/routines) (`/schedule`, cloud), [Desktop scheduled tasks](https://code.claude.com/docs/en/desktop-scheduled-tasks) (local, Desktop app), [Channels](https://code.claude.com/docs/en/channels) (event-pushed, research preview) | A **daemon-free crontab/launchd trigger** for the case none of the three native options cover: **CLI-only, headless** environments (no Desktop app, no cloud access, no channel-plugin setup). |
| `/claude-warp-new-agent` | `.claude/agents/` (hand-edited, or ask Claude directly — the native `/agents` **wizard was removed** in v2.1.198) | A scaffolder that fills a subagent definition (name, description, model, tools, persona) from a one-line role, since Claude Code now expects hand-editing or an ad hoc request. |
| `/claude-warp-sync` | — (no native equivalent) | Reads every Claude Code release in the unscanned window and **retires ClaudeWarp's own components** once a native feature genuinely covers them — the mechanism that keeps this whole table from going stale. Also watchlists the *routing* decisions above (this page) against future releases. |
| `/claude-warp-converge` | — (no native equivalent) | Reconciles actual repo state against a contract's intent + task list, classifies every gap (missing/partial/contradicts/unrequested), and append-only re-tickets what's unmet — instead of silently retrying or declaring done. |
| `/claude-warp-ledger` | — (no native equivalent) | A persistent, queryable, **cross-session** closure ledger (`.claudewarp/ledger.jsonl`) — what shipped, what was surfaced to a human, what a converge pass reconciled — filterable by kind/slug/event/date. |
| `/claude-warp-retro` | — (no native equivalent) | A retrospective over a loop/goal/harness's own state file + git history: what worked, what failed, concrete improvements, written to `RETRO.md`. |
| `/claude-warp-release` | Native [`/code-review`](https://code.claude.com/docs/en/code-review), [`/security-review`](https://code.claude.com/docs/en/commands) (diff-level checks) | A release-**readiness** gate distinct from "diff reviewed" or "PR merged" — packages evidence (VERSION/CHANGELOG/tag/tree state) into a two-tier verdict: hard BLOCK on mechanical boundaries, advisory WARN+Surface on the bump-severity judgment. Read-only; prints the tag/release commands rather than running them. |
| `/claude-warp-inventory` | `claude agents`, `/mcp`, `/hooks` (each shows one slice) | One self-inspection sweep across installed skills, agents, hooks, and loops together — versions, health issues, stale entries — in a single report. |

---

## What this means in practice

If a task is **small and you're at the terminal**: use native `/goal` or `/plan` directly — no
scaffold needed, and both skills above say so and stop. If it's **recurring but only while you're
working**: native `/loop`. Reach for a ClaudeWarp scaffold when the work must survive **you not
being there** — a different session, a crashed process, a headless server — because that
durability is exactly what the native primitives don't carry across a session boundary today.

This boundary is not static: `/claude-warp-sync` re-reads Claude Code's changelog and narrows this
table over time as native features absorb more of it. → [Architecture — Native vs
harness](architecture.md#native-vs-harness) is the living, mechanical version of this same
comparison.
