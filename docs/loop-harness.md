# ClaudeWarp — Loop Harness

A thin, self-pruning harness that installs loop engineering infrastructure into any project.

## What it is (and isn't)

**ClaudeWarp installs only what Claude Code does not already provide natively.**

The table below defines the boundary. It is kept current by `/harness-sync` — when a
"Harness" row becomes native, it is automatically migrated and logged.

| Capability | Where it lives | Native or Harness? |
|---|---|---|
| Skill auto-loading | `.claude/skills/` | **Native** (v2.1.157) |
| Subagent fan-out | `Agent`, `TaskCreate` | **Native** (v2.1.154) |
| Worktree isolation | `EnterWorktree`, `isolation: "worktree"` | **Native** |
| Scheduling runtime | `~/.claude/scheduled-tasks/`, `/loop` | **Native** |
| Memory / context | `CLAUDE.md`, `/memory` | **Native** |
| Code review | `/code-review --fix`, `/simplify` | **Native** |
| Fallback / reliability | `fallbackModel`, auto mode | **Native** |
| **Scheduling guards** | `scripts/guard-<name>.sh` | **Harness** |
| **External trigger** | `scripts/run-<name>.sh` + crontab snippet | **Harness** |
| **Cross-run structured state** | `<NAME>_LOG.md` + dedup logic | **Harness** |
| **Changelog monitor / self-pruner** | `/harness-sync` skill | **Harness** |
| **Loop scaffolder** | `/new-loop` skill | **Harness** |

## The three harness skills

### `/setup-loop-harness`
Configures ClaudeWarp in the current project. Detects project type (Node/Python/Go/generic),
fills `CLAUDE.md` with real context, creates directory structure, writes `harness-manifest.json`,
and commits everything.

### `/new-loop "goal"`
Scaffolds a complete loop from a one-line description:
- `.claude/skills/<slug>/SKILL.md` — the loop procedure
- `scripts/guard-<slug>.sh` — prevents double-runs
- `scripts/run-<slug>.sh` — headless runner (cron-ready)
- `<SLUG>_LOG.md` — append-only state file
- `scripts/trigger-<slug>.crontab` — paste-ready cron entry

### `/harness-sync`
Re-reads the Claude Code changelog on every run. For each harness component that has
become native in the installed version of Claude Code:
- Sets `status: "superseded"` in `harness-manifest.json`
- Logs a migration note in `HARNESS_SYNC_LOG.md`
- Adds a deprecation notice to the affected skill file

This is what keeps ClaudeWarp from rotting as Claude Code evolves.

## What a loop consists of

Every loop scaffolded by `/new-loop` has four parts:

```
.claude/skills/<slug>/SKILL.md     ← what Claude does (phases + stopping condition)
scripts/guard-<slug>.sh            ← run-once-per-day / weekday guard
scripts/run-<slug>.sh              ← headless runner invoked by cron
<SLUG>_LOG.md                      ← append-only state: dedup anchor + history
```

The trigger (cron/launchd) lives outside the repo in the OS scheduler — `install.sh`
never writes to crontab; it prints the snippet and asks you to paste it.

## Companion resource

The conceptual foundation for loop engineering is documented in
[ClaudeLoops](https://github.com/lucagattoni/Claude-Loops) — the knowledge base of
patterns, failure modes, and building blocks that ClaudeWarp implements.
