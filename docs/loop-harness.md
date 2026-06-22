# ClaudeWarp — Loop Harness Reference

Architecture, skills in depth, and templates reference.

---

## Native vs harness

ClaudeWarp installs only what Claude Code does not already provide. This boundary
is tracked in `harness-manifest.json` and kept current by `/claude-warp-sync`.

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
| **Changelog monitor / self-pruner** | `/claude-warp-sync` | **Harness** |
| **Loop scaffolder** | `/claude-warp-new-loop`, `/claude-warp-new-harness` | **Harness** |
| **Agent scaffolder** | `/claude-warp-new-agent` | **Harness** |

When a harness row becomes native, `/claude-warp-sync` marks it `superseded`,
logs a migration note in `HARNESS_SYNC_LOG.md`, and adds a deprecation notice
to the affected skill.

---

## Skills

### `/claude-warp-setup`

Per-project installer. Detects project type (Node / Python / Go / Rust / generic),
fills `CLAUDE.md` with real context, creates directory structure, writes
`harness-manifest.json`, and commits.

Install path: `skills/claude-warp-setup/SKILL.md`

---

### `/claude-warp-new-loop "goal"`

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

Install path: `skills/claude-warp-new-loop/SKILL.md`

---

### `/claude-warp-new-harness "goal"`

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

Install path: `skills/claude-warp-new-harness/SKILL.md`

---

### `/claude-warp-new-agent "role"`

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

Install path: `skills/claude-warp-new-agent/SKILL.md`

---

### `/claude-warp-sync`

Synchronises the harness against the current Claude Code version.

1. Fetches the Claude Code changelog (cached 24h at `~/.claude/cache/changelog.md`)
2. Scans for evidence that any active component is now native
3. Marks superseded components in `harness-manifest.json`
4. Writes migration notes to `HARNESS_SYNC_LOG.md`
5. Adds deprecation notices to affected skill files
6. Commits if anything changed

Install path: `skills/claude-warp-sync/SKILL.md`

---

### `/claude-warp-update`

Pulls the latest ClaudeWarp skills from GitHub into this project.

1. Reads `harness-manifest.json` for the current installed version
2. Fetches the skills directory listing from the ClaudeWarp GitHub repo
3. For each installed skill: fetches the remote SKILL.md and compares with local
4. Applies updates, installs new skills, and reports orphans (removed upstream)
5. Updates `harness-manifest.json` version and commits

Install path: `skills/claude-warp-update/SKILL.md`

---

### `/claude-warp-sync-research`

Developer-facing tool — scans [ClaudeLoops](https://github.com/lucagattoni/Claude-Loops)
on GitHub for patterns not yet implemented in ClaudeWarp. Run from the ClaudeWarp
source repo, not from installed projects.

1. Runs `/claude-warp-sync` as a preliminary step
2. Fetches the ClaudeLoops topic index and latest news digest from GitHub
3. Fetches the ClaudeWarp skills and templates inventory from GitHub
4. Rates each gap High / Medium / Low
5. Appends findings to `CLAUDE_WARP_UPDATE_LOG.md` and prints a summary

Does not implement anything — surfaces findings only.

Install path: `skills/claude-warp-sync-research/SKILL.md`

---

## Templates

| Template | Used by | Purpose |
|---|---|---|
| `CLAUDE.md.tpl` | `claude-warp-setup` | Base loop engineering context for a project |
| `loop.SKILL.md.tpl` | `claude-warp-new-loop` | Loop skill skeleton: guard → state → work → verify → write → stop |
| `guard.sh.tpl` | `claude-warp-new-loop` | Run-once-per-day / weekday-only guard script |
| `run-headless.sh.tpl` | `claude-warp-new-loop` | Single-agent headless runner with `--max-turns` and `--max-budget-usd` |
| `run-fanout.sh.tpl` | `claude-warp-new-loop` | Parallel fan-out runner: one agent per item, concurrency cap, per-item logs |
| `trigger.crontab.tpl` | `claude-warp-new-loop` | Reference cron entry (not installed — paste into `crontab -e`) |
| `harness-manifest.json.tpl` | `claude-warp-setup` | Version + components registry |
| `VISION.md.tpl` | `claude-warp-new-harness` | Anchor file: high-level goal and success criteria |
| `AGENTS.md.tpl` | `claude-warp-new-harness` | Anchor file: agent roles and handoff protocol |
| `PROMPT.md.tpl` | `claude-warp-new-harness` | Anchor file: current work unit; edit to re-task the loop |

---

## Loop anatomy

Every loop scaffolded by `/claude-warp-new-loop` follows this phase sequence:

```
Phase 1 — Guard check     prevent duplicate runs
Phase 2 — Load state      read STATE_FILE; recover IN_PROGRESS tasks
Phase 3 — Do the work     goal-specific logic (expanded by /claude-warp-new-loop)
Phase 3b — Verify         run check command; iterate on failure
Phase 4 — Write results   append dated entry to STATE_FILE; commit
Stopping condition        SUCCESS / SKIP / FAILURE defined per loop
```

Every harness scaffolded by `/claude-warp-new-harness` follows this flow:

```
Initializer (once)  →  features.json populated
Runner loop         →  coding agent invoked per pending task
Coding agent        →  reads session-init → executes one task → commits → stops
```
