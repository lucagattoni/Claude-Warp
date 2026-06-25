# ClaudeWarp Update Log

Append-only. Updated by `/claude-warp-update` on each run.

---

## 2026-06-25 08:11 IST

### claude-warp-sync output
```
claude-warp-sync complete ✓

Claude Code version : 2.1.191 (up from 2.1.186)
Components checked  : 6
Superseded          : 1 (skill-distribution-workaround — native since v2.1.157, unchanged)
New native features : none that supersede additional ClaudeWarp components
Next sync           : tomorrow (or run /claude-warp-sync anytime)
```

### Claude-Loops last updated
8690690 (2026-06-25T07:06:56Z) — updated today (34 docs total)

### Feature gaps

#### High priority

- **Goal Engineering (doc-30)** — NEW DOC. Goals are distinct from loops: one-shot, stop when a verifiable criterion is met ("Loops discover work. Goals finish it."). ClaudeWarp has `new-harness` for multi-stage recurring work but no `claude-warp-new-goal` skill. Gap: scaffold GOAL.md (Objective/Done conditions/Guardrails/Execution log schema), G0–G3 readiness scoring, and a simple run-once script. This fills the distinct "bounded, non-recurring task" use case that `new-loop` and `new-harness` don't cover.
  Source: [Goal Engineering](docs/30-goal-engineering.md)

- **Hooks as loop verification circuit breaker (doc-12)** — EXISTING DOC, NOT YET COVERED. The `asyncRewake + Stop hook` pattern is a deterministic alternative to Phase 3b's manual verify-and-retry: a Stop hook blocks turn end (exit code 2) until a check passes, then Claude re-enters with failure context automatically. ClaudeWarp has no hook templates or `claude-warp-new-hook` skill. Phase 3b currently relies on the LLM judging whether to retry — a hook makes it deterministic. Doc also covers destructive-command-blocking and audit-logging hooks.
  Source: [Hooks](docs/12-hooks.md)

- **Six-State Verdict System (doc-04 updated)** — EXISTING DOC, UPDATED. Loop template stopping condition has three states (SUCCESS / SKIP / FAILURE). Doc-04 now defines six: pass / fail / handoff / timeout / stopped / awaiting-merge. Missing states: `handoff` (human judgment required), `timeout` (budget exhausted — should resume, not retry), `stopped` (security gate triggered — investigate, don't auto-retry), `awaiting-merge` (external dependency — monitor, don't retry). Targeted update to `loop.SKILL.md.tpl` Stopping condition section.
  Source: [Verification](docs/04-verification.md)

#### Medium priority

- **Human-in-the-Loop escalation triggers (doc-14)** — EXISTING DOC, NOT COVERED. Concrete thresholds to hard-code in CLAUDE.md.tpl and loop template: 3 consecutive test failures with no clear fix → escalate; cost estimate exceeding $10 → escalate; destructive operations (DROP, DELETE without WHERE, push to main) → escalate; 3 consecutive blocks of same action → escalate. Currently missing from both the CLAUDE.md.tpl context and the loop Stopping condition.
  Source: [Human-in-the-Loop](docs/14-human-in-the-loop.md)

- **Three-Agent Harness: QA/Evaluator (doc-24 updated)** — UPDATED DOC. Current `new-harness` creates Planner + Coder (2 agents). Doc-24 now fully specifies a Planner + Generator + QA/Evaluator triad. QA uses Playwright or equivalent to test against 20+ predefined criteria. Could be an optional `--with-qa` phase in `new-harness` that scaffolds a third agent definition and wires it into the runner.
  Source: [Harness Patterns](docs/24-harness-patterns.md)

- **Loop Patterns Catalog (doc-34)** — NEW DOC. Seven named production-ready patterns with parameters and cost metrics: Daily Triage, PR Babysitter, CI Sweeper, Dependency Sweeper, Post-Merge Cleanup, Changelog Drafter, Issue Triage. `claude-warp-new-loop` derives all parameters from scratch; recognising a named pattern could pre-fill schedule, turn cap, budget, stop condition, and safety rules (e.g. CI Sweeper's mandatory early-exit rule). Could be a recipe lookup at the start of `new-loop` Phase 1.
  Source: [Loop Patterns Catalog](docs/34-loop-patterns.md)

#### Low priority

- **Fleet Engineering (doc-23)** — NEW DOC. F0–F3 maturity model and fleet economics (cost attribution per agent against fleet ceiling). Useful when a project runs 3+ loops. Out of scope for now but `harness-manifest.json` already tracks `loops[]` — adding `budget` and `actual_cost` per loop entry would be the minimal entry point.
  Source: [Fleet Engineering](docs/23-fleet-engineering.md)

- **Claude Tag (doc-31)** — NEW DOC. Ambient Slack-based loops with channel identity and self-scheduling. Too platform-specific for generic ClaudeWarp templates.

### Implementation

- ✅ Six-state verdict system — `loop.SKILL.md.tpl` stopping condition extended with pass/skip/fail/handoff/timeout/stopped; handoff and timeout have distinct semantics preventing runaway retries
- ✅ Goal Engineering (`claude-warp-new-goal`) — new skill; GOAL.md schema, G0-G3 scoring (G0 stops, G1-G2 warn in-file), run-once script with GOAL.md-based resume
- ✅ Hooks circuit breaker (`claude-warp-new-hook`) — new skill; verify-before-stop (asyncRewake + exit 2), destructive-block (PreToolUse), audit-log (async PostToolUse); exit code semantics documented inline
- ✅ Human-in-the-Loop escalation — `CLAUDE.md.tpl` escalation rules table; `loop.SKILL.md.tpl` escalation pointer; thresholds: 3 failures, 3 blocks, $10, destructive ops
- ✅ Three-agent harness QA evaluator — `new-harness` Phase 5b; `--with-qa` flag; QA agent reverts task to pending with feedback in features.json if criteria fail
- ✅ Loop Patterns Catalog recipe lookup — `new-loop` Phase 1; seven named patterns with pre-defined parameters; safety rules embedded into generated SKILL.md Phase 3
- ✅ `claude-warp-sync-research` skill updated — auto-implement Phase 7 with pre/post review loop (overlap → scope → devil's advocate → convention; journey trace → regression → devil's advocate → reference audit → fresh reader)
- ⏭ Fleet Engineering — skipped (Low priority; enterprise-scale, out of current scope)
- ⏭ Claude Tag — skipped (Low priority; Slack-specific, not generically implementable)

Released as v0.8.0 (MINOR: 2 new skills, 1 skill with new Phase 7, template and harness extensions).

### No gap found (v0.7.0 already covers)
- Background Agents (`--bg --worktree` fan-out) — doc-29 ✓
- Routines (cloud scheduling) — doc-28 ✓
- Inner/Outer Dual Loop (`--retry`) — doc-25 ✓
- DOER/CHECKER (Phase 3c) — doc-07 ✓
- Loop Contract header — doc-27 ✓
- Two-part harness (Planner + Coder) — doc-26 / doc-24 ✓
- Subagent scaffolding — claude-warp-new-agent ✓
- Cost & turn control (`--effort high`, `--max-budget-usd`) — doc-11 ✓
- Headless mode — run-headless.sh.tpl — doc-09 ✓
- Fan-out — run-fanout.sh.tpl — doc-10 ✓
- Guard scripts (scheduling guards) — guard.sh.tpl ✓
- Cross-context state (STATE_FILE / LOG.md) — doc-16 ✓
- Anchor files (VISION/AGENTS/PROMPT) — new-harness ✓
- Skills as SDLC phases — doc-06 ✓
- CLAUDE.md layering — doc-05 ✓

---

## 2026-06-23 17:16 IST

### claude-warp-sync output
```
claude-warp-sync complete ✓

Claude Code version : 2.1.186
Components checked  : 6
Superseded          : 1 (skill-distribution-workaround — native since v2.1.157)
Next sync           : tomorrow (or run /claude-warp-sync anytime)
```

### Claude-Loops last updated
e495626 (2026-06-23T15:59:00Z) — updated today

### Feature gaps

#### High priority

- **Background Agents / `--bg --worktree` (doc 29)**: `claude --bg --worktree` is now native and directly supersedes ClaudeWarp's `run-fanout.sh.tpl` approach. Currently the fan-out runner spawns raw bash background processes with no git isolation; `claude --bg --worktree` provides isolated worktrees per item, session IDs for monitoring, and `claude agents`/`claude logs` for observability. The fan-out template should be rewritten to use `claude --bg --worktree`, collect session IDs, and poll via `claude agents --json` until all sessions complete. This fixes the git race condition documented in the current template warning.
  Source: [Background Agents](docs/29-background-agents.md)

- **Routines — cloud-hosted scheduling (doc 28)**: Claude Code now supports cloud-hosted loop execution via `/schedule` (cron, API trigger, GitHub event trigger). This partially supersedes ClaudeWarp's `external-trigger` component (crontab + launchd snippets). Two actions needed: (1) add `native_since` to `external-trigger` in `harness-manifest.json.tpl` so `/claude-warp-sync` can flag it; (2) update `docs/usage.md` Scheduling section to present Routines as the preferred path (no local machine required) with crontab/launchd as the fallback. Minimum cron interval for Routines is 1 hour.
  Source: [Routines](docs/28-routines.md)

#### Medium priority

- **Inner/Outer Dual Loop for harness recovery (doc 25)**: When `claude-warp-new-harness` hits MAX_ITER with tasks still pending, the runner exits with error and stops. The Inner/Outer Dual Loop pattern says repeated inner-loop failure should trigger an outer strategic reset — re-run the initializer to revise the task breakdown, rather than aborting. Implement as an optional `--retry` flag on the harness runner: if MAX_ITER is hit, re-invoke the initializer with a "previous attempt failed on task N, revise the breakdown" prompt, then restart the coding loop.
  Source: [Long-Running Agents](docs/25-long-running-agents.md)

- **DOER/CHECKER pattern (doc 07)**: ClaudeWarp has `claude-warp-new-agent` for scaffolding checker agents, but neither the harness runner nor the loop template includes a CHECKER step. The DOER/CHECKER pattern requires a fresh independent session (never the same agent) to validate output. Add an optional Phase 3c to `loop.SKILL.md.tpl`: "If a checker agent exists for this loop, invoke it on the result before committing." `claude-warp-new-harness` could also scaffold a CHECKER agent alongside the initializer.
  Source: [Subagents](docs/07-subagents.md)

#### Low priority

- **Background agent session management docs (doc 29)**: `claude agents`, `claude logs <id>`, `claude attach <id>`, `claude respawn <id>` — none of these are documented in ClaudeWarp's `docs/usage.md`. A "Monitoring running loops" section covering these commands would help users debug stuck or long-running headless invocations.
  Source: [Background Agents](docs/29-background-agents.md)

- **Fleet Engineering (doc 23)**: Enterprise-scale governance and observability — out of ClaudeWarp's current scope. Note for future: if ClaudeWarp ever adds a multi-project dashboard or registry, fleet engineering patterns would apply.

### No gap found
- Loop Contract (TRIGGER/SCOPE/ACTION/BUDGET/STOP/REPORT) — just added in current session ✓
- Budget caps / --effort high — all runners ✓
- Guard scripts (scheduling guards) — guard.sh.tpl ✓
- Two-part harness (initializer + coding agent) — claude-warp-new-harness ✓
- git-based recovery — session-init pattern ✓
- Verification phase (Phase 3b) — loop.SKILL.md.tpl ✓
- IN_PROGRESS recovery — loop template Phase 2 ✓
- MAX_ITER guard — harness runner ✓
- Anchor files (VISION/AGENTS/PROMPT) — new-harness ✓
- Fan-out parallelism — run-fanout.sh.tpl ✓
- Subagent scaffolding — claude-warp-new-agent ✓
- Cron/launchd triggers — trigger.crontab.tpl, docs/usage.md ✓
- Headless mode — run-headless.sh.tpl ✓
- Cross-context state — STATE_FILE pattern ✓

---

## 2026-06-22 16:12 IST

### harness-sync output
```
Claude Code version : 2.1.185
Components checked  : 6
Superseded          : 0 (skill-distribution-workaround already flagged native_since 2.1.157 — will self-trigger on first /harness-sync in an installed project)
Note                : No harness-manifest.json in source repo (expected)
```

### Claude-Loops last updated
`29f75ff` — 2026-06-22 (already up to date)

---

### Feature gaps

#### High priority

- **`--max-budget-usd` missing from `run-headless.sh.tpl`**: The headless runner has `--max-turns` but no hard cost cap. Per doc 11 (Cost Control) and the Loop Contract (doc 27), `--max-budget-usd` is mandatory for all unattended runs. Without it a runaway loop burns unlimited tokens.
  Source: [Cost & Turn Control](docs/11-cost-control.md), [Loop Contract](docs/27-loop-contract.md)

- **Loop Contract not enforced in `new-loop`**: The skill derives `MAX_TURNS` as a "conservative estimate" but never asks for or documents BUDGET (max-budget-usd) or a verifiable STOP condition. The Loop Contract says a loop without these is "not a loop — it is a runaway process."
  Source: [Loop Contract](docs/27-loop-contract.md)

- **Recovery pattern missing from `loop.SKILL.md.tpl`**: Phase 2 reads the state file for the last run but does not implement the recovery invariant: *"if last entry is IN_PROGRESS, treat it as incomplete and restart it."* Without this, a crashed loop silently skips its interrupted task on resume.
  Source: [Long-Running Agents](docs/25-long-running-agents.md)

#### Medium priority

- **Verification phase missing from `loop.SKILL.md.tpl`**: Phase 3 is a comment placeholder. Doc 04 says verification is non-negotiable — every loop needs a check it can run (test suite, linter, exit code, evaluator subagent) as a non-skippable phase.
  Source: [Verification](docs/04-verification.md)

- **No `.claude/agents/` scaffolding**: Doc 03 shows specialized subagents defined in `.claude/agents/<name>.md` with frontmatter (name, description, tools, model). No ClaudeWarp skill or template covers this. A `new-agent` skill would close the gap.
  Source: [Building Blocks](docs/03-building-blocks.md)

- **Two-part harness not scaffolded**: Doc 24 describes an initializer agent (generates a JSON feature list + session init file) paired with a coding agent (executes tasks with git-based recovery). `new-loop` creates a single-agent loop only. A `new-harness` skill would cover complex multi-stage goals.
  Source: [Harness Patterns](docs/24-harness-patterns.md)

#### Low priority

- **Fan-out runner template absent**: Doc 10 shows a parallel fan-out pattern (generate task list → `while read | claude & … wait`). Useful for batch migrations. Could be `templates/run-fanout.sh.tpl`.
  Source: [Fan-Out](docs/10-fan-out.md)

- **Anchor File Pattern not scaffolded**: Doc 27 defines VISION.md / CLAUDE.md / AGENTS.md / PROMPT.md as four context files the loop reads at startup. `new-loop` creates SKILL.md + state file but not this set. Low priority since CLAUDE.md is already handled by `setup-loop-harness`.
  Source: [Loop Contract](docs/27-loop-contract.md)

---

### Already covered by ClaudeWarp

- Scheduling guards → `guard.sh.tpl` ✓
- External trigger (cron/launchd) → `trigger.crontab.tpl` ✓
- Headless runner → `run-headless.sh.tpl` ✓
- Loop scaffolding → `new-loop` ✓
- Cross-run state files → `new-loop` Phase 2d ✓
- Changelog monitor / self-pruning → `harness-sync` ✓
- Skills as SDLC scaffolding → SKILL.md structure ✓
- Memory (state surviving across runs) → append-only state file per loop ✓

---
