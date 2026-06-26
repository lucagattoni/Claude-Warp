# ClaudeWarp

> The loop harness for Claude Code. Scaffold, guard, and schedule autonomous loops in any project.

---

## What it is

ClaudeWarp installs the infrastructure layer that Claude Code does not provide natively: loop scaffolding, scheduling guards, headless runners, and a self-pruning mechanism that retires harness components as Claude Code absorbs them.

It is intentionally thin. Anything Claude Code already handles — subagents, worktrees, memory, code review, scheduling runtime — is documented and referenced, not reimplemented.

### One model: Plan vs Shape

A **plan** is *what* you want done, specified well enough to verify (any size). A **shape** is *how* it runs:

- **single-shot** (goal) — runs once, stops at a verifiable criterion (a *small* plan)
- **loop** — recurs on a trigger (a *recurring* plan)
- **harness** — decomposed into subplans, each its own unit of work (a *big* plan)

"A goal" isn't the opposite of "a plan" — a goal is a small, single-shot plan. You write the plan with `/claude-warp-contract`; it classifies the shape for you. → [full model & aims](docs/concepts.md)

---

## Install

**Prerequisites:** Claude Code installed, and a git repository as your working directory.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lucagattoni/Claude-Warp/main/install.sh)
```

This runs `/claude-warp-setup` autonomously: detects your project type, fills `CLAUDE.md` and `harness-manifest.json`, installs all skills under `.claude/skills/`, and commits everything in one go.

→ Full installation guide: [docs/install.md](docs/install.md)

---

## Quick start

```bash
# Scaffold a daily loop from a one-line goal
claude -p '/claude-warp-new-loop "summarise new GitHub Issues every morning"'

# Test it before scheduling
bash scripts/run-<slug>.sh

# Schedule it — cloud-hosted (preferred)
claude -p "/schedule"

# Or wire to local cron (paste the generated snippet)
crontab -e

# Keep skills up to date
claude -p "/claude-warp-update"
```

→ Full usage guide: [docs/usage.md](docs/usage.md)

---

## Skills

| Skill | What it does |
|---|---|
| `/claude-warp-setup` | Per-project installer |
| `/claude-warp-contract "goal"` | **Start here** — the single adaptive entry: negotiate a [plan](docs/concepts.md), auto-route to its shape (single-shot / loop / harness), and hand off to the scaffolder. Scales questions to complexity |
| `/claude-warp-new-loop "goal"` | Scaffold a recurring single-agent loop or fan-out loop |
| `/claude-warp-new-goal "goal"` | Scaffold a one-shot bounded goal that runs once and stops at a verifiable criterion |
| `/claude-warp-new-harness "goal"` | Scaffold a two-part harness for large multi-stage goals |
| `/claude-warp-new-agent "role"` | Scaffold a specialized subagent in `.claude/agents/` |
| `/claude-warp-new-hook "description"` | Scaffold a hook (8 patterns): verify-before-stop, destructive-block, audit-log, subagent-chain, security-scan, evidence-gate, kill-switch, steer |
| `/claude-warp-inventory` | Self-inspect installed skills, agents, hooks, loops — report versions and health issues |
| `/claude-warp-retro "slug"` | Retrospective on a loop — what worked, what failed, top 3 improvements; writes RETRO.md |
| `/claude-warp-sync` | Prune harness components superseded by Claude Code |
| `/claude-warp-update` | Pull the latest ClaudeWarp skills from GitHub |
| `/claude-warp-sync-research` | Scan Claude-Loops and GitHub for new patterns; implement findings automatically |

---

## Docs

| Document | Contents |
|---|---|
| [docs/concepts.md](docs/concepts.md) | **Read first** — plans, shapes (goal/loop/harness), and `/claude-warp-contract`: what they are and their aims |
| [docs/install.md](docs/install.md) | Prerequisites, install command, verification, update, uninstall |
| [docs/usage.md](docs/usage.md) | Loop types, scheduling, iterating, keeping the harness current |
| [docs/loop-harness.md](docs/loop-harness.md) | Architecture: native vs harness boundary, skills in depth, templates reference |
| [docs/goal-readiness.md](docs/goal-readiness.md) | G0–G3 readiness scale — how to specify goals so agents know when they are done |

---

## Companion

[ClaudeLoops](https://github.com/lucagattoni/Claude-Loops) is the knowledge base behind ClaudeWarp — loop engineering patterns, failure modes, and building blocks.

---

## Design

ClaudeWarp separates two kinds of thing, and they move in opposite directions:

- **Native-replaceable components** (skill distribution, scheduling guards, cross-run state) are *meant to shrink*. Each tracks a `native_since` field in `harness-manifest.json`; when `/claude-warp-sync` confirms Claude Code covers it natively, the component is marked superseded and retired.
- **Loop-engineering workflow skills** (scaffolding, the contract negotiator, checkers, hooks, retrospectives) are the durable value. These track the *practice* of loop engineering, not gaps in Claude Code — as the discipline matures ("the harness now matters more than the model"), this layer grows.

So the harness as plumbing shrinks toward zero, while the harness as method deepens. Conflating the two is the easy mistake; `/claude-warp-sync` only ever retires the former.

---

## Developing

Working on ClaudeWarp itself? `scripts/dev.sh` self-hosts the skills (symlinks them so they run as live `/claude-warp-*` commands in this repo) and verifies source integrity:

```bash
scripts/dev.sh selfhost   # symlink skills into .claude/skills/ (single source of truth)
scripts/dev.sh verify     # deterministic checks: integrity, install copy contract, docs coherence
```

See the [Developing ClaudeWarp](docs/loop-harness.md#developing-claudewarp) section for the full command reference and what `verify` does (and doesn't) cover.
