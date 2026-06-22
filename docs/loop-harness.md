# ClaudeWarp — Loop Harness Reference

Architecture, skills in depth, and templates reference.

---

## Native vs harness

ClaudeWarp installs only what Claude Code does not already provide. This boundary
is tracked in `harness-manifest.json` and kept current by `/harness-sync`.

| Capability | Where it lives | Status |
|---|---|---|
| Skill auto-loading | `.claude/skills/` | **Native** (v2.1.157) |
| Subagent fan-out | `Agent` tool, `TaskCreate` | **Native** |
| Worktree isolation | `EnterWorktree`, `isolation: "worktree"` | **Native** |
| Scheduling runtime | `~/.claude/scheduled-tasks/`, `/loop` | **Native** |
| Memory / context | `CLAUDE.md`, `/memory` | **Native** |
| Code review | `/code-review`, `/simplify` | **Native** |
| **Scheduling guards** | `scripts/guard-<name>.sh` | **Harness** |
| **External trigger** | `scripts/run-<name>.sh` + crontab snippet | **Harness** |
| **Cross-run structured state** | `<NAME>_LOG.md` + dedup logic | **Harness** |
| **Changelog monitor / self-pruner** | `/harness-sync` | **Harness** |
| **Loop scaffolder** | `/new-loop`, `/new-harness` | **Harness** |
| **Agent scaffolder** | `/new-agent` | **Harness** |

When a harness row becomes native, `/harness-sync` marks it `superseded`,
logs a migration note in `HARNESS_SYNC_LOG.md`, and adds a deprecation notice
to the affected skill.

---

## Skills

### `/setup-loop-harness`

Per-project installer. Detects project type (Node / Python / Go / Rust / generic),
fills `CLAUDE.md` with real context, creates directory structure, writes
`harness-manifest.json`, and commits.

Install path: `skills/setup-loop-harness/SKILL.md`

---

### `/new-loop "goal"`

Scaffolds a complete single-agent loop from a one-line goal description.

**Derives from the goal:**
- `SKILL_SLUG`, `SKILL_NAME`, `SKILL_DESCRIPTION`
- `STATE_FILE` — append-only tracking file
- `DEFAULT_SCHEDULE` — suggested cron expression
- `MAX_TURNS` — hard turn cap
- `MAX_BUDGET_USD` — hard cost cap (default $2.00)
- `STOP_CONDITION` — verifiable signal that the loop succeeded
- `ALLOWED_TOOLS` — minimum tool set

**Files created:**

| File | Purpose |
|---|---|
| `.claude/skills/<slug>/SKILL.md` | Loop procedure with phases: guard → state → work → verify → write → stop |
| `scripts/guard-<slug>.sh` | Prevents double-runs (once per day / weekdays only) |
| `scripts/run-<slug>.sh` | Headless runner; picks `run-headless.sh.tpl` or `run-fanout.sh.tpl` based on goal shape |
| `<SLUG>_LOG.md` | Append-only state with IN_PROGRESS recovery |
| `scripts/trigger-<slug>.crontab` | Reference cron snippet (not installed automatically) |

Install path: `skills/new-loop/SKILL.md`

---

### `/new-harness "goal"`

Scaffolds a two-part harness for goals too large for a single loop. Based on
Anthropic Engineering's ["Effective Harnesses for Long-Running Agents"](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

**Two roles:**
- **Initializer agent** — reads the goal and scope; produces a bounded JSON task list; runs once
- **Coding agent** — executes one task at a time; commits after each; reads session-init at the start of every context window for crash recovery

**Files created:**

| File | Purpose |
|---|---|
| `.claude/agents/<slug>-initializer.md` | Planner agent definition |
| `<slug>-features.json` | Task queue: `pending` → `in_progress` → `done` / `failed` |
| `<slug>-session-init.md` | Read by coding agent at every context window start |
| `VISION.md` | High-level goal and success criteria (anchor file) |
| `AGENTS.md` | Role definitions and handoff protocol (anchor file) |
| `PROMPT.md` | Current work unit — edit to re-task without changing rules (anchor file) |
| `scripts/run-<slug>.sh` | Runner: initializer once, then coding agent loop until all tasks done |

Install path: `skills/new-harness/SKILL.md`

---

### `/new-agent "role"`

Scaffolds a specialized subagent definition for use inside loops and harnesses.

**Derives from the role:**
- `AGENT_NAME` — kebab-case identifier
- `AGENT_MODEL` — Opus 4.8 for deep analysis; Sonnet 4.6 for routine work; Haiku 4.5 for fast lookups
- `AGENT_TOOLS` — minimum tool set for the role
- `AGENT_PERSONA` — expertise, focus, output format, and constraints

**Files created:**

| File | Purpose |
|---|---|
| `.claude/agents/<name>.md` | Subagent definition with frontmatter and persona |

Install path: `skills/new-agent/SKILL.md`

---

### `/harness-sync`

Synchronises the harness against the current Claude Code version.

1. Fetches the Claude Code changelog (cached 24h at `~/.claude/cache/changelog.md`)
2. Scans for evidence that any active component is now native
3. Marks superseded components in `harness-manifest.json`
4. Writes migration notes to `HARNESS_SYNC_LOG.md`
5. Adds deprecation notices to affected skill files
6. Commits if anything changed

Install path: `skills/harness-sync/SKILL.md`

---

### `/claude-warp-update`

Checks for ClaudeWarp improvements from [ClaudeLoops](https://github.com/lucagattoni/Claude-Loops).

1. Runs `/harness-sync` as a preliminary step
2. Pulls the latest Claude-Loops repo
3. Reads the full topic index and recent news findings
4. Compares against the current ClaudeWarp inventory
5. Rates each gap High / Medium / Low
6. Appends findings to `CLAUDE_WARP_UPDATE_LOG.md` and prints a summary

Does not implement anything — surfaces findings only.

Install path: `skills/claude-warp-update/SKILL.md`

---

## Templates

| Template | Used by | Purpose |
|---|---|---|
| `CLAUDE.md.tpl` | `setup-loop-harness` | Base loop engineering context for a project |
| `loop.SKILL.md.tpl` | `new-loop` | Loop skill skeleton: guard → state → work → verify → write → stop |
| `guard.sh.tpl` | `new-loop` | Run-once-per-day / weekday-only guard script |
| `run-headless.sh.tpl` | `new-loop` | Single-agent headless runner with `--max-turns` and `--max-budget-usd` |
| `run-fanout.sh.tpl` | `new-loop` | Parallel fan-out runner: one agent per item, concurrency cap, per-item logs |
| `trigger.crontab.tpl` | `new-loop` | Reference cron entry (not installed — paste into `crontab -e`) |
| `harness-manifest.json.tpl` | `setup-loop-harness` | Version + components registry |
| `VISION.md.tpl` | `new-harness` | Anchor file: high-level goal and success criteria |
| `AGENTS.md.tpl` | `new-harness` | Anchor file: agent roles and handoff protocol |
| `PROMPT.md.tpl` | `new-harness` | Anchor file: current work unit; edit to re-task the loop |

---

## Loop anatomy

Every loop scaffolded by `/new-loop` follows this phase sequence:

```
Phase 1 — Guard check     prevent duplicate runs
Phase 2 — Load state      read STATE_FILE; recover IN_PROGRESS tasks
Phase 3 — Do the work     goal-specific logic (expanded by /new-loop)
Phase 3b — Verify         run check command; iterate on failure
Phase 4 — Write results   append dated entry to STATE_FILE; commit
Stopping condition        SUCCESS / SKIP / FAILURE defined per loop
```

Every harness scaffolded by `/new-harness` follows this flow:

```
Initializer (once)  →  features.json populated
Runner loop         →  coding agent invoked per pending task
Coding agent        →  reads session-init → executes one task → commits → stops
```
