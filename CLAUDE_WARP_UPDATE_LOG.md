# ClaudeWarp Update Log

Append-only. Updated by `/claude-warp-update` on each run.

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
