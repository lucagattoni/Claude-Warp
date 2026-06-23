# ClaudeWarp Update Log

Append-only. Updated by `/claude-warp-update` on each run.

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
