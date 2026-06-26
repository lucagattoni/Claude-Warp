# ClaudeWarp — Usage

---

## Start here

Don't know which scaffold you need? Let ClaudeWarp choose:

```bash
claude -p '/claude-warp-new "summarise new GitHub Issues every morning"'
```

`/claude-warp-new` is a router — it assesses the goal (recurring vs one-shot,
single-stage vs multi-stage) and delegates to the right scaffolder below. If the goal
is vague or high-risk, run `/claude-warp-contract "goal"` first: it interviews you to
produce a complete, risk-classified contract before any scaffolding (see
[goal-readiness.md](goal-readiness.md) for the readiness scale it gates on).

## Choosing a scaffold

The router picks one of these; you can also invoke them directly. Full per-skill
reference is in [loop-harness.md](loop-harness.md).

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

`--retry` clears the task list, re-invokes the initializer with failure context, and runs one final coding pass with a revised task breakdown.

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

## Scheduling

### Cloud-hosted (Routines) — preferred when available

Claude Code Routines run on Anthropic infrastructure — no local machine, no daemon required. Set up with the built-in `/schedule` command:

```bash
# Interactive setup
claude -p "/schedule"
```

Routines support three trigger types:
- **Scheduled** — cron-style (minimum 1-hour interval)
- **API** — HTTP POST to a webhook endpoint; fires asynchronously
- **GitHub events** — PR creation, release, push to a path

Permission prompts during a Routine run are routed to your main session asynchronously rather than blocking execution.

### Local scheduling (crontab / launchd)

Use this when you need sub-hourly intervals, access to the local filesystem at runtime, or are self-hosted.

**crontab:**
```bash
crontab -e
# paste the contents of scripts/trigger-<slug>.crontab
```

**launchd (macOS — more reliable than crontab):**

Create `~/Library/LaunchAgents/com.claudewarp.<slug>.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>             <string>com.claudewarp.<slug></string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/path/to/project/scripts/run-<slug>.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>    <integer>9</integer>
    <key>Minute</key>  <integer>0</integer>
  </dict>
  <key>RunAtLoad</key> <false/>
</dict>
</plist>
```

```bash
launchctl load ~/Library/LaunchAgents/com.claudewarp.<slug>.plist
```

Timestamps use local system time. Confirm your OS timezone with `date` before scheduling.

---

## Keeping the harness current

**Sync with Claude Code** — prunes harness components that Claude Code now handles natively:
```bash
claude -p "/claude-warp-sync"
```

**Update ClaudeWarp skills** — pulls the latest skill versions from GitHub:
```bash
claude -p "/claude-warp-update"
```

**Research new patterns** — scans Claude-Loops on GitHub for concepts not yet in ClaudeWarp (developer tool, run from the ClaudeWarp source repo):
```bash
claude -p "/claude-warp-sync-research"
```

**Check the install** — zero-LLM scan of installed skills, agents, hooks, and loop state files; flags missing files, stale model IDs, or loops needing attention:
```bash
claude -p "/claude-warp-inventory"
```

---

## Monitoring running loops

Background agents and fan-out runners surface sessions through the Claude Code agent dashboard:

```bash
# Interactive dashboard — shows all running and completed sessions
claude agents

# Machine-readable — useful for scripting
claude agents --json | jq '.[].status'

# Tail output from a specific session
claude logs <session-id>

# Attach your terminal to a running session
claude attach <session-id>

# Restart a completed or failed session with full history
claude respawn <session-id>
```

For headless single-agent runners, output goes to `logs/<slug>-<date>.log`.

---

## Iterating on a loop

After a run, inspect the output:
```bash
cat <SLUG>_LOG.md
```

To improve the loop, edit `.claude/skills/<slug>/SKILL.md` — specifically Phase 3 ("Do the work") and Phase 3b ("Verify"). The guard prevents double-runs on the same day; to force a re-run during testing, invoke the skill directly:
```bash
claude -p "/<slug>"
```

After a loop has several runs behind it, `/claude-warp-retro "<slug>"` reads its state file and git history and reports what worked, what failed, and the top improvements to make — a structured alternative to reading the log yourself.
