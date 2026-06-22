---
name: claude-warp-new-harness
description: Scaffold a two-part harness for complex multi-stage goals — an initializer agent that produces a JSON feature list, and a coding agent that executes tasks with git-based recovery
---

Scaffold a two-part harness for the goal: `$ARGUMENTS`

Use this skill when a goal is too large or multi-stage for a single loop — it needs
a planner that breaks it down and a worker that executes unit by unit, resuming
safely after any crash.

## Phase 1 — Understand the goal

Parse `$ARGUMENTS` as a plain-English goal.
Derive:
- `HARNESS_NAME` — human-readable name (e.g. "Auth Module Refactor")
- `HARNESS_SLUG` — kebab-case (e.g. `auth-refactor`)
- `HARNESS_GOAL` — one sentence: what done looks like
- `SCOPE` — which files / directories the coding agent may touch
- `MAX_TURNS_INIT` — turns for the initializer (default 10; it only plans)
- `MAX_TURNS_WORKER` — turns per task unit for the coding agent (default 30)
- `MAX_BUDGET_USD` — hard cost cap per full harness run (default 5.00)
- `VERIFICATION_CMD` — the command that confirms a task unit is done
  (e.g. `npm test`, `pytest`, `cargo test`; or "none — human review required")

Get local time:
```bash
date '+%Y-%m-%d %H:%M %Z'
```

## Phase 2 — Create directory structure and anchor files

```bash
mkdir -p .claude/agents
mkdir -p scripts
mkdir -p logs
```

**Anchor files** — the loop reads all four at startup; updating `PROMPT.md` re-tasks
the loop without changing its rules or goal:

Read `templates/VISION.md.tpl` and fill:
- `{{PROJECT_NAME}}` → `HARNESS_NAME`
- `{{VISION_GOAL}}` → `HARNESS_GOAL`
- `{{SKILL_SLUG}}` → `HARNESS_SLUG`
- `{{PROMPT_FILE}}` → `PROMPT.md`
Write to `VISION.md`.

Read `templates/AGENTS.md.tpl` and fill:
- `{{PROJECT_NAME}}` → `HARNESS_NAME`
- `{{HARNESS_SLUG}}`, `{{FEATURES_FILE}}` → `<HARNESS_SLUG>-features.json`
Write to `AGENTS.md`.

Read `templates/PROMPT.md.tpl` and fill:
- `{{PROJECT_NAME}}` → `HARNESS_NAME`
- `{{CURRENT_TASK}}` → first task description (leave as placeholder if unknown)
Write to `PROMPT.md`.

(`CLAUDE.md` is already managed by `setup-loop-harness` — do not overwrite it.)

## Phase 3 — Write the feature list schema

Create `<HARNESS_SLUG>-features.json` with an empty task queue:

```json
{
  "goal": "<HARNESS_GOAL>",
  "scope": "<SCOPE>",
  "verification": "<VERIFICATION_CMD>",
  "generated_at": null,
  "tasks": []
}
```

Each task entry (populated by the initializer) will have the shape:
```json
{
  "id": 1,
  "title": "short task title",
  "description": "what to implement",
  "files_in_scope": ["src/auth/login.ts"],
  "status": "pending",
  "result": null
}
```

Valid status values: `pending` → `in_progress` → `done` | `failed`.

## Phase 4 — Write the session init file

Create `<HARNESS_SLUG>-session-init.md`:

```markdown
# <HARNESS_NAME> — Session Init

Read this file at the start of every coding agent context window.

## Goal
<HARNESS_GOAL>

## Scope
The coding agent may only touch: <SCOPE>

## Task queue
Read `<HARNESS_SLUG>-features.json`. Find the first task with status `pending`
or `in_progress`. Execute that task only. When done, set status to `done` and
commit. Then stop — do not start the next task.

## Recovery
If the task was already `in_progress` when you started, treat it as incomplete.
Re-read the relevant files and redo the work from scratch.

## Verification
After completing each task, run: `<VERIFICATION_CMD>`
Do not mark a task `done` until verification passes.

## Hard limits
- Touch only files listed in `files_in_scope` for the current task
- One git commit per completed task: `git commit -m "harness(<HARNESS_SLUG>): task <id> — <title>"`
- Never mark all tasks done yourself — stop after one task and let the runner re-invoke you
```

## Phase 5 — Write the initializer agent

Create `.claude/agents/<HARNESS_SLUG>-initializer.md`:

```markdown
---
name: <HARNESS_SLUG>-initializer
description: Reads the goal and scope, then populates <HARNESS_SLUG>-features.json with a bounded task list
model: claude-opus-4-8
tools: Read,Glob,Grep,Edit
---

You are a planning agent. Your only job is to analyse the codebase and produce a
task list — you do not write code.

Read the goal and scope from `<HARNESS_SLUG>-session-init.md`.
Read all relevant files within scope.

Produce a task list in `<HARNESS_SLUG>-features.json`:
- Break the goal into the smallest independently committable units
- Each task must be completable in a single coding agent session (<MAX_TURNS_WORKER> turns)
- List concrete files in `files_in_scope` for each task
- Set `generated_at` to the current timestamp
- Set all task statuses to `pending`

Output: write the updated JSON and stop. Do not implement anything.
```

## Phase 6 — Write the runner script

Create `scripts/run-<HARNESS_SLUG>.sh`:

```bash
#!/usr/bin/env bash
# Two-part harness runner for: <HARNESS_NAME>
# 1. Run initializer once (if tasks list is empty)
# 2. Loop: invoke coding agent for each pending task until all done
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

mkdir -p logs
LOG="logs/<HARNESS_SLUG>-$(date '+%Y%m%d-%H%M').log"
echo "[$(date '+%Y-%m-%d %H:%M %Z')] Harness start: <HARNESS_NAME>" >> "$LOG"

FEATURES="<HARNESS_SLUG>-features.json"

# Step 1 — initializer (only if tasks array is empty)
TASK_COUNT=$(python3 -c "import json,sys; d=json.load(open('$FEATURES')); print(len(d['tasks']))" 2>/dev/null || echo 0)
if [ "$TASK_COUNT" -eq 0 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Running initializer..." >> "$LOG"
  claude \
    --permission-mode auto \
    --max-turns <MAX_TURNS_INIT> \
    --max-budget-usd 1.00 \
    --allowedTools "Read,Glob,Grep,Edit" \
    -p "Use the <HARNESS_SLUG>-initializer agent to populate $FEATURES" \
    >> "$LOG" 2>&1
fi

# Step 2 — coding agent loop
PENDING=1
while [ "$PENDING" -gt 0 ]; do
  PENDING=$(python3 -c "
import json,sys
d=json.load(open('$FEATURES'))
print(len([t for t in d['tasks'] if t['status'] in ('pending','in_progress')]))" 2>/dev/null || echo 0)

  if [ "$PENDING" -eq 0 ]; then break; fi

  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Running coding agent ($PENDING tasks remaining)..." >> "$LOG"
  claude \
    --permission-mode auto \
    --max-turns <MAX_TURNS_WORKER> \
    --max-budget-usd <MAX_BUDGET_USD> \
    --allowedTools "Read,Edit,Bash,Glob,Grep" \
    -p "Read <HARNESS_SLUG>-session-init.md, then execute the next pending task in $FEATURES" \
    >> "$LOG" 2>&1
done

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Harness complete: <HARNESS_NAME>" >> "$LOG"
```

Make executable:
```bash
chmod +x scripts/run-<HARNESS_SLUG>.sh
```

## Phase 7 — Register in manifest

Read `harness-manifest.json` (if present). Append to a `harnesses` array (create
if absent):
```json
{
  "slug": "<HARNESS_SLUG>",
  "name": "<HARNESS_NAME>",
  "features_file": "<HARNESS_SLUG>-features.json",
  "session_init": "<HARNESS_SLUG>-session-init.md",
  "created_at": "<LOCAL_TIMESTAMP>"
}
```
Write back.

## Phase 8 — Commit

```bash
git add .claude/agents/<HARNESS_SLUG>-initializer.md \
        <HARNESS_SLUG>-features.json \
        <HARNESS_SLUG>-session-init.md \
        VISION.md AGENTS.md PROMPT.md \
        scripts/run-<HARNESS_SLUG>.sh \
        harness-manifest.json
git commit -m "feat(harness): scaffold <HARNESS_SLUG>"
```

## Phase 9 — Report

```
Two-part harness scaffolded ✓

  Initializer : .claude/agents/<HARNESS_SLUG>-initializer.md
  Feature list: <HARNESS_SLUG>-features.json
  Session init: <HARNESS_SLUG>-session-init.md
  Anchor files: VISION.md, AGENTS.md, PROMPT.md
  Runner      : scripts/run-<HARNESS_SLUG>.sh

To run:
  bash scripts/run-<HARNESS_SLUG>.sh

The runner will:
  1. Invoke the initializer once to populate the task list
  2. Loop: invoke the coding agent for each pending task until all are done

Budget cap: $<MAX_BUDGET_USD> per coding-agent invocation
Verification: <VERIFICATION_CMD>
```
