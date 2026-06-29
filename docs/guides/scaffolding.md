# Guide — Choosing & running a scaffold

Task-oriented how-to for invoking each scaffold. New to ClaudeWarp? Start with the
[Quick start](../quickstart.md) instead — it walks one happy path end to end. For *what each skill
does* in depth, see the [Skills reference](../reference/skills.md).

## Let the contract choose

Don't know which scaffold you need? Let ClaudeWarp choose:

```bash
claude -p '/claude-warp-contract "summarise new GitHub Issues every morning"'
```

`/claude-warp-contract` is the single entry point — it specifies your plan, **auto-routes to the
shape** (single-shot vs loop vs harness), scales the questions to the complexity, and hands off to
the right scaffolder below. It interviews you to produce a complete, risk-classified contract before
any scaffolding (see [goal-readiness.md](../goal-readiness.md) for the readiness scale it gates on).

| Scaffold | When to use | Skill |
|---|---|---|
| **Single-agent loop** | Recurring task, one context per run — daily digests, monitors, audits | `/claude-warp-new-loop` |
| **Fan-out loop** | Same task against many independent items in parallel | `/claude-warp-new-loop` (auto-selected) |
| **One-shot goal** | Runs once and stops at a verifiable criterion — a migration, a scan | `/claude-warp-new-goal` |
| **Two-part harness** | Large multi-stage goal spanning many context windows | `/claude-warp-new-harness` |

---

## Single-agent loop

Describe your goal in one sentence:

```bash
claude -p '/claude-warp-new-loop "check GitHub Issues daily and summarise new ones"'
```

ClaudeWarp derives all parameters from the goal — schedule, turn cap, budget cap, stop condition, state file — and creates:

| File | Purpose |
|---|---|
| `.claude/skills/<slug>/SKILL.md` | The loop procedure — edit Phase 3 to customise |
| `scripts/guard-<slug>.sh` | Prevents duplicate runs (once per day, weekdays only) |
| `scripts/run-<slug>.sh` | Headless runner — invoke via cron or launchd |
| `<SLUG>_LOG.md` | Append-only state, used for dedup and history |
| `scripts/trigger-<slug>.crontab` | Paste-ready cron snippet |

**Run it manually first:**
```bash
bash scripts/run-<slug>.sh
cat logs/<slug>-$(date '+%Y%m%d').log
```

---

## Fan-out loop (parallel)

When the goal processes many independent items, ClaudeWarp selects the fan-out runner automatically:

```bash
claude -p '/claude-warp-new-loop "migrate all Python files in src/ to async/await"'
```

The runner uses `claude --bg --worktree` — each item gets its own background agent in an isolated git worktree, preventing file conflicts. Session IDs are collected and polled until all complete; results appear in `logs/<slug>-<run-id>.log`.

Fill in the generated `scripts/run-<slug>.sh`:
- `TASK_LIST_COMMAND` — command that outputs one item per line (e.g. `find src -name "*.py"`)
- `TASK_PROMPT_PREFIX` — prompt passed to each agent (e.g. `"Migrate this file to async/await:"`)

Monitor live progress:
```bash
claude agents
```

---

## Two-part harness

For goals too large for one loop — the harness uses a planner agent to break the work into bounded tasks, then a worker agent to execute them one at a time with git-based recovery:

```bash
claude -p '/claude-warp-new-harness "refactor the auth module to use the new token provider"'
```

Creates:
- **Initializer agent** — runs once, reads the goal, writes a task list to `<slug>-features.json`
- **Session-init file** — read by the coding agent at the start of every context window
- **Anchor files** — `VISION.md` (goal), `AGENTS.md` (roles), `PROMPT.md` (current task)
- **Runner script** — calls the initializer once, then loops the coding agent until all tasks are done

**Run it:**
```bash
bash scripts/run-<slug>.sh

# If the coding loop stalls (MAX_ITER reached), trigger Inner/Outer Dual Loop:
bash scripts/run-<slug>.sh --retry
```

`--retry` classifies the stall (code → retry in place · spec → re-decompose · intent → Surface) and, in the spec case, clears the task list, re-invokes the initializer with failure context, and runs one final coding pass with a revised breakdown.

**Re-task without changing rules:** edit `PROMPT.md` and commit — the next invocation picks it up.

---

## Specialized subagents

For loops that need an independent reviewer, security auditor, or domain specialist:

```bash
claude -p '/claude-warp-new-agent "security reviewer: audits diffs for injection flaws and auth issues"'
```

Creates `.claude/agents/<name>.md` with persona, model, and tool constraints. The model is chosen automatically: Opus for deep analysis, Sonnet for routine work, Haiku for fast lookups.

Reference from a skill: `"Use a subagent to review the diff in src/auth/ — report only correctness issues."`

---

**Next:** [schedule it](scheduling.md) · [set its autonomy level](deployment.md) ·
[monitor it](monitoring.md) · [iterate on it](iterating.md).
