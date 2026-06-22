# ClaudeWarp

> The loop harness for Claude Code. Scaffold, guard, and schedule autonomous loops in any project — one command.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lucagattoni/Claude-Warp/main/install.sh)
```

---

## What it is

ClaudeWarp installs the infrastructure layer that Claude Code does not provide natively: loop scaffolding, scheduling guards, headless runners, and a self-pruning mechanism that retires harness components as Claude Code absorbs them.

It is intentionally thin. Anything Claude Code already handles — subagents, worktrees, memory, code review, scheduling runtime — is documented and referenced, not reimplemented.

---

## Skills

| Skill | What it does |
|---|---|
| `/setup-loop-harness` | Per-project installer |
| `/new-loop "goal"` | Scaffold a single-agent loop |
| `/new-harness "goal"` | Scaffold a two-part harness (initializer + coding agent) for multi-stage goals |
| `/new-agent "role"` | Scaffold a specialized subagent in `.claude/agents/` |
| `/harness-sync` | Prune harness components superseded by Claude Code |
| `/claude-warp-update` | Check Claude-Loops for new patterns to implement |

---

## Docs

| Document | Contents |
|---|---|
| [docs/guide.md](docs/guide.md) | Step-by-step: install → scaffold → run → schedule |
| [docs/loop-harness.md](docs/loop-harness.md) | Architecture: native vs harness boundary, skills in depth, templates reference |

---

## Companion

[ClaudeLoops](https://github.com/lucagattoni/Claude-Loops) is the knowledge base behind ClaudeWarp — loop engineering patterns, failure modes, and building blocks.

---

## Design

ClaudeWarp is designed to shrink over time. Each harness component tracks a `native_since` field in `harness-manifest.json`. When `/harness-sync` confirms Claude Code covers it natively, the component is marked superseded and retired.
