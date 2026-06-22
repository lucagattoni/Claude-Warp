# ClaudeWarp

> The loop harness for Claude Code. Scaffold, guard, and schedule autonomous loops in any project — one command.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lucagattoni/Claude-Warp/main/install.sh)
```

---

## What it does

ClaudeWarp installs **only the layer Claude Code does not provide natively**:

| What you need | How ClaudeWarp provides it |
|---|---|
| Scaffold a loop from a goal | `/new-loop "your goal"` |
| Prevent duplicate runs | `scripts/guard-<slug>.sh` (run-once-per-day) |
| Run unattended | `scripts/run-<slug>.sh` → wire to cron / launchd |
| Stay current as Claude Code evolves | `/harness-sync` — reads the CC changelog and prunes superseded components automatically |
| Keep ClaudeWarp itself up to date | `/claude-warp-update` — runs harness-sync then scans Claude-Loops for new patterns to implement |

Everything Claude Code already handles natively (subagents, worktrees, scheduling runtime, `/code-review`, memory) is **not** reimplemented here — it's just documented and referenced.

---

## Quick start

```bash
# In any git project:
git clone https://github.com/lucagattoni/Claude-Warp.git /tmp/claude-warp
bash /tmp/claude-warp/install.sh

# Scaffold your first loop:
claude -p '/new-loop "check for new issues in my GitHub repo daily"'

# Run it:
bash scripts/run-check-new-issues.sh

# Keep the harness current:
claude -p "/harness-sync"
```

See [docs/guide.md](docs/guide.md) for the full 6-step walkthrough.

---

## Skills installed

| Skill | What it does |
|---|---|
| `/setup-loop-harness` | Per-project configurator — fills CLAUDE.md, creates dirs, writes manifest |
| `/new-loop "goal"` | Scaffolds a complete loop: SKILL.md + guard + runner + state + trigger |
| `/harness-sync` | Claude Code changelog monitor — prunes components that have become native |
| `/claude-warp-update` | Runs harness-sync then scans Claude-Loops for patterns not yet in ClaudeWarp; surfaces prioritised feature gaps |
| `/new-agent "role"` | Scaffolds a specialized subagent in `.claude/agents/` with persona, model, and tool constraints |
| `/new-harness "goal"` | Scaffolds a two-part harness: initializer agent (produces JSON task list) + coding agent (executes tasks with git-based recovery) |

---

## Companion

ClaudeWarp is the tooling. [ClaudeLoops](https://github.com/lucagattoni/Claude-Loops) is
the knowledge base — patterns, failure modes, and building blocks behind loop engineering.

---

## Self-pruning design

Claude Code ships new features frequently. ClaudeWarp tracks what it provides in
`harness-manifest.json` with a `components[]` list. Each component has a `native_since`
field. When `/harness-sync` detects that a component is now native, it:

1. Marks it `"superseded"` in the manifest
2. Logs a migration note in `HARNESS_SYNC_LOG.md`
3. Adds a deprecation notice to the affected skill

**ClaudeWarp is designed to shrink over time, not grow.**
