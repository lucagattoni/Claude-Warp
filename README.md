<p align="center">
  <img src="assets/claude-warp-header.png" alt="Claude-Warp — a loop harness for Claude Code" width="820">
</p>

<h1 align="center">ClaudeWarp</h1>

<p align="center">
  <em>The loop harness for Claude Code. Scaffold, guard, and schedule autonomous tasks in any project.</em>
</p>

<p align="center">
  <a href="https://github.com/lucagattoni/Claude-Warp/actions/workflows/verify.yml"><img src="https://github.com/lucagattoni/Claude-Warp/actions/workflows/verify.yml/badge.svg" alt="verify"></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/lucagattoni/Claude-Warp"><img src="https://api.scorecard.dev/projects/github.com/lucagattoni/Claude-Warp/badge" alt="OpenSSF Scorecard"></a>
</p>

<p align="center">
  📖 <strong><a href="https://lucagattoni.github.io/Claude-Warp/">Read the docs</a></strong> — the same pages, as a searchable 3-column site.
</p>

ClaudeWarp installs the infrastructure layer Claude Code doesn't provide natively — loop scaffolding,
scheduling guards, headless runners, readiness gates, and a self-pruning mechanism that retires
components as Claude Code absorbs them. You describe *what you want and how to know it's done*; it
scaffolds the right thing to run it — once, on a schedule, or as a large multi-stage job — and stops
when it should.

It is intentionally thin. Anything Claude Code already handles — subagents, worktrees, memory, code
review, scheduling runtime — is referenced, not reimplemented.

---

## Pick your path

| | Start here |
|---|---|
| 🐣 **New to this?** | **[Quick start](docs/quickstart.md)** — run your first autonomous task in 10 minutes, zero prior knowledge assumed. Then [Concepts](docs/concepts.md) for the "why". |
| 🚀 **Claude Code veteran?** | Skip the intro → **[Skills reference](docs/reference/skills.md)** (all 15, in depth) · [Architecture](docs/reference/architecture.md) · [Developing](docs/reference/developing.md). The function table below is your map. |

---

## Install

**Prerequisites:** Claude Code installed, and a git repository as your working directory.

**Option A — curl installer** (also runs project setup):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/lucagattoni/Claude-Warp/main/install.sh)
```

Runs `/claude-warp-setup` autonomously: detects your project type, fills `CLAUDE.md` and
`harness-manifest.json`, installs all skills under `.claude/skills/`, and commits.

**Option B — Claude Code plugin** (skills available everywhere, namespaced):

```bash
/plugin marketplace add lucagattoni/Claude-Warp
/plugin install claude-warp@claude-warp
```

Then run `/claude-warp:claude-warp-setup` in a project to materialise `CLAUDE.md` +
`harness-manifest.json`. → Full guide: **[docs/install.md](docs/install.md)**

---

## Skills

`/claude-warp-contract` is the one door — describe anything and it routes to the right scaffold. The
rest you can also invoke directly.

| Skill | What it does |
|---|---|
| `/claude-warp-setup` | Per-project installer |
| `/claude-warp-contract "goal"` | **Start here** — the single adaptive entry: negotiate a [plan](docs/concepts.md), auto-route to its shape (single-shot / loop / harness), and hand off to the scaffolder. Scales questions to complexity |
| `/claude-warp-new-loop "goal"` | Scaffold a recurring single-agent loop or fan-out loop |
| `/claude-warp-new-goal "goal"` | Scaffold a one-shot bounded goal that runs once and stops at a verifiable criterion |
| `/claude-warp-new-harness "goal"` | Scaffold a two-part harness for large multi-stage goals |
| `/claude-warp-converge` | Reconcile the actual repo state against contract + task intent, classify gaps (missing/partial/contradicts/unrequested), and append-only re-ticket the unmet pieces (read-only; idempotent) |
| `/claude-warp-release` | Release-readiness gate distinct from "done"/"merged" — packages evidence and emits a two-tier verdict (BLOCK on mechanical boundaries: VERSION/CHANGELOG/tag/`[Unreleased]`/dirty tree; WARN+Surface on the bump-severity judgment). Read-only; prints the tag/release commands, never runs them |
| `/claude-warp-new-agent "role"` | Scaffold a specialized subagent in `.claude/agents/` |
| `/claude-warp-new-hook "description"` | Scaffold a hook (9 patterns): verify-before-stop, destructive-block, audit-log, subagent-chain, security-scan, evidence-gate, review-gate, kill-switch, steer |
| `/claude-warp-inventory` | Self-inspect installed skills, agents, hooks, loops — report versions and health issues |
| `/claude-warp-retro "slug"` | Retrospective on a loop — what worked, what failed, top 3 improvements; writes RETRO.md |
| `/claude-warp-ledger` | Persistent cross-session closure ledger — `record`/`query` closure events (shipped/surfaced/converged) in append-only `.claudewarp/ledger.jsonl`; the queryable "what happened, in order" that survives across sessions (over executable `scripts/ledger.sh`) |
| `/claude-warp-sync` | Prune harness components superseded by Claude Code |
| `/claude-warp-update` | Pull the latest ClaudeWarp skills from GitHub |
| `/claude-warp-sync-research` | Scan Claude-Loops and GitHub for new patterns; implement findings automatically |

---

## Docs

| Document | Contents |
|---|---|
| [docs/quickstart.md](docs/quickstart.md) | **🐣 Start here** — your first autonomous task in 10 minutes (goal, then loop) |
| [docs/concepts.md](docs/concepts.md) | The model — plans, shapes (goal/loop/harness), and `/claude-warp-contract` |
| [docs/install.md](docs/install.md) | Prerequisites, install command, verification, update, uninstall |
| [docs/goal-readiness.md](docs/goal-readiness.md) | G0–G3 readiness scale — how to specify goals so agents know when they're done |
| **How-to guides** | [scaffolding](docs/guides/scaffolding.md) · [scheduling](docs/guides/scheduling.md) · [deployment posture](docs/guides/deployment.md) · [monitoring](docs/guides/monitoring.md) · [iterating](docs/guides/iterating.md) |
| **Reference** (🚀) | [skills](docs/reference/skills.md) · [templates](docs/reference/templates.md) · [architecture](docs/reference/architecture.md) · [developing](docs/reference/developing.md) |

---

## Companion

[ClaudeLoops](https://github.com/lucagattoni/Claude-Loops) is the knowledge base behind ClaudeWarp —
loop engineering patterns, failure modes, and building blocks.

---

## Notes

- **One model, three shapes.** A *plan* is what you want done; *goal* / *loop* / *harness* are the
  shapes it can take (small / recurring / big). You don't pick by hand — `/claude-warp-contract` does.
  → [the full model](docs/concepts.md).
- **The harness shrinks; the method deepens.** Native-replaceable plumbing is *meant* to retire as
  Claude Code absorbs it, while the loop-engineering workflow skills are the durable value.
  → [the two directions](docs/reference/architecture.md#native-vs-harness).
- **Working on ClaudeWarp itself?** `scripts/dev.sh selfhost` symlinks the skills as live commands and
  `scripts/dev.sh verify` runs the deterministic CI checks. → [Developing](docs/reference/developing.md).
