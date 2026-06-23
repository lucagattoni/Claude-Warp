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

(`CLAUDE.md` is already managed by `claude-warp-setup` — do not overwrite it.)

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
# Usage: bash scripts/run-<HARNESS_SLUG>.sh [--retry]
# --retry  If the coding loop stalls at MAX_ITER, re-invoke the initializer
#          with failure context (Inner/Outer Dual Loop) before one final pass.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

RETRY=0
[[ "${1:-}" == "--retry" ]] && RETRY=1

mkdir -p logs
LOG="logs/<HARNESS_SLUG>-$(date '+%Y%m%d-%H%M').log"
echo "[$(date '+%Y-%m-%d %H:%M %Z')] Harness start: <HARNESS_NAME>${RETRY:+ (--retry)}" >> "$LOG"

FEATURES="<HARNESS_SLUG>-features.json"

run_initializer() {
  local prompt="${1:-Use the <HARNESS_SLUG>-initializer agent to populate $FEATURES}"
  claude \
    --permission-mode auto \
    --max-turns <MAX_TURNS_INIT> \
    --max-budget-usd 1.00 \
    --effort high \
    --allowedTools "Read,Glob,Grep,Edit" \
    -p "$prompt" \
    >> "$LOG" 2>&1
}

run_coding_loop() {
  local max_iter=50 iter=0 pending=1
  while [ "$pending" -gt 0 ] && [ "$iter" -lt "$max_iter" ]; do
    iter=$((iter+1))
    pending=$(python3 -c "
import json,sys
d=json.load(open('$FEATURES'))
print(len([t for t in d['tasks'] if t['status'] in ('pending','in_progress')]))" 2>/dev/null || echo -1)

    if [ "$pending" -eq -1 ]; then
      echo "[$(date '+%Y-%m-%d %H:%M %Z')] ERROR: could not parse $FEATURES — aborting." >> "$LOG"
      return 1
    fi
    [ "$pending" -eq 0 ] && break

    echo "[$(date '+%Y-%m-%d %H:%M %Z')] Coding agent (iter $iter/$max_iter, $pending remaining)..." >> "$LOG"
    claude \
      --permission-mode auto \
      --max-turns <MAX_TURNS_WORKER> \
      --max-budget-usd <MAX_BUDGET_USD> \
      --effort high \
      --allowedTools "Read,Edit,Bash,Glob,Grep" \
      -p "Read <HARNESS_SLUG>-session-init.md, then execute the next pending task in $FEATURES" \
      >> "$LOG" 2>&1
  done

  if [ "$iter" -ge "$max_iter" ] && [ "$pending" -gt 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] WARNING: MAX_ITER=$max_iter reached, $pending tasks still pending." >> "$LOG"
    return 2
  fi
  return 0
}

# ── Step 1: Initializer ───────────────────────────────────────────────────────
TASK_COUNT=$(python3 -c "import json,sys; d=json.load(open('$FEATURES')); print(len(d['tasks']))" 2>/dev/null || echo 0)
if [ "$TASK_COUNT" -eq 0 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Running initializer..." >> "$LOG"
  if ! run_initializer; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] ERROR: initializer failed — aborting." >> "$LOG"
    exit 1
  fi
fi

# ── Step 2: Coding loop ───────────────────────────────────────────────────────
run_coding_loop
LOOP_RC=$?

# ── Step 3: Inner/Outer Dual Loop — retry on stall ───────────────────────────
if [ "$LOOP_RC" -eq 2 ] && [ "$RETRY" -eq 1 ]; then
  STUCK=$(python3 -c "
import json
d=json.load(open('$FEATURES'))
titles=[t['title'] for t in d['tasks'] if t['status'] in ('pending','in_progress')]
print(', '.join(titles[:5]))" 2>/dev/null || echo "unknown")

  echo "[$(date '+%Y-%m-%d %H:%M %Z')] --retry: clearing tasks, re-invoking initializer with stall context..." >> "$LOG"
  python3 -c "import json; d=json.load(open('$FEATURES')); d['tasks']=[]; json.dump(d,open('$FEATURES','w'),indent=2)"

  RETRY_PROMPT="The previous run of <HARNESS_SLUG> stalled with these tasks incomplete: ${STUCK}. \
Re-read <HARNESS_SLUG>-session-init.md, analyse why those tasks stalled (too large? ambiguous scope?), \
and write a revised task breakdown in $FEATURES with smaller, more granular tasks."

  if ! run_initializer "$RETRY_PROMPT"; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] ERROR: retry initializer failed — aborting." >> "$LOG"
    exit 1
  fi

  run_coding_loop
  LOOP_RC=$?
fi

[ "$LOOP_RC" -ne 0 ] && exit "$LOOP_RC"
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

  # If the loop stalls (MAX_ITER reached), trigger Inner/Outer Dual Loop:
  bash scripts/run-<HARNESS_SLUG>.sh --retry

The runner will:
  1. Invoke the initializer once to populate the task list
  2. Loop: invoke the coding agent for each pending task until all are done
  3. On --retry: if stalled, re-invoke the initializer with failure context
     and try once more with a revised task breakdown

Budget cap   : $<MAX_BUDGET_USD> per coding-agent invocation
Verification : <VERIFICATION_CMD>

Optional DOER/CHECKER — add an independent reviewer:
  claude -p '/claude-warp-new-agent "checker for <HARNESS_SLUG>: \
    reviews completed tasks for correctness before the next task starts"'
```
