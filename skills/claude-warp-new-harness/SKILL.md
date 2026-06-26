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
  "depends_on": [],
  "wave": 1,
  "status": "pending",
  "result": null
}
```

Valid status values: `pending` → `in_progress` → `done` | `failed`.

**Wave scheduling:** the initializer must also populate `depends_on` (list of task IDs
that must be `done` before this task starts) and `wave` (integer, derived from the
dependency graph via topological sort: all tasks with no dependencies are wave 1, tasks
depending only on wave 1 tasks are wave 2, etc.). Tasks in the same wave are independent
and can run in parallel. The runner uses this to launch wave N tasks concurrently before
starting wave N+1.

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

## Phase 5b — Write the QA evaluator agent (optional — only if `--with-qa` requested)

If the user's goal involves output that can be independently tested or graded
(UI components, generated code, docs, APIs), scaffold a QA/Evaluator agent.

Derive:
- `QA_TOOLS` — tools the evaluator needs (e.g. `Bash,Read` for test runners; add MCP tools for browser testing)
- `QA_CRITERIA` — 3–5 concrete, testable grading criteria derived from the goal

Create `.claude/agents/<HARNESS_SLUG>-qa.md`:

```markdown
---
name: <HARNESS_SLUG>-qa
description: Evaluates completed tasks against predefined criteria; reports pass/fail with actionable feedback before the next task starts
model: claude-sonnet-4-6
tools: <QA_TOOLS>
---

You are a QA evaluator. You do not implement — you grade completed work.

Read `<HARNESS_SLUG>-features.json` to identify the most recently completed task.
Read the files listed in `files_in_scope` for that task.

Grade against these criteria:
<QA_CRITERIA — one per line, each machine-checkable>

For each criterion: PASS or FAIL with one sentence of evidence.
If any criterion FAILs: write a `qa_feedback` field on the task in features.json
and set status back to `pending`. The coding agent will re-read the feedback.
If all criteria PASS: write `"qa_status": "approved"` on the task. Stop.
```

**Runner integration note:** the runner script in Phase 6 will invoke this agent
after each coding agent turn when `--with-qa` is active. See Phase 6.

## Phase 6 — Write the runner script

Create `scripts/run-<HARNESS_SLUG>.sh`:

```bash
#!/usr/bin/env bash
# Two-part harness runner for: <HARNESS_NAME>
# Usage: bash scripts/run-<HARNESS_SLUG>.sh [--retry] [--with-qa] [--parallel-waves]
# --retry           Inner/Outer Dual Loop: re-invoke initializer on MAX_ITER stall.
# --with-qa         After each coding agent turn, invoke the QA evaluator agent;
#                   coding agent re-works the task if QA fails.
# --parallel-waves  Run tasks within each wave concurrently using claude --bg --worktree;
#                   tasks in different waves still run sequentially (dependency order).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

RETRY=0
WITH_QA=0
PARALLEL_WAVES=0
for arg in "$@"; do
  [[ "$arg" == "--retry" ]] && RETRY=1
  [[ "$arg" == "--with-qa" ]] && WITH_QA=1
  [[ "$arg" == "--parallel-waves" ]] && PARALLEL_WAVES=1
done

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

  # Get sorted list of wave numbers
  WAVES=$(python3 -c "
import json
d=json.load(open('$FEATURES'))
waves=sorted(set(t.get('wave',1) for t in d['tasks']))
print(' '.join(str(w) for w in waves))" 2>/dev/null || echo "1")

  for wave in $WAVES; do
    wave_pending=$(python3 -c "
import json
d=json.load(open('$FEATURES'))
print(len([t for t in d['tasks'] if t.get('wave',1)==$wave and t['status'] in ('pending','in_progress')]))" 2>/dev/null || echo 0)
    [ "$wave_pending" -eq 0 ] && continue

    echo "[$(date '+%Y-%m-%d %H:%M %Z')] Wave $wave: $wave_pending tasks..." >> "$LOG"

    if [ "$PARALLEL_WAVES" -eq 1 ] && [ "$wave_pending" -gt 1 ]; then
      # Launch wave tasks in parallel via --bg --worktree
      TASK_IDS=$(python3 -c "
import json
d=json.load(open('$FEATURES'))
ids=[str(t['id']) for t in d['tasks'] if t.get('wave',1)==$wave and t['status'] in ('pending','in_progress')]
print(' '.join(ids))" 2>/dev/null || echo "")

      AGENT_IDS=()
      for tid in $TASK_IDS; do
        agent_id=$(claude \
          --permission-mode auto \
          --max-turns <MAX_TURNS_WORKER> \
          --max-budget-usd <MAX_BUDGET_USD> \
          --effort high \
          --allowedTools "Read,Edit,Bash,Glob,Grep" \
          --bg --worktree \
          -p "Read <HARNESS_SLUG>-session-init.md, then execute task id=$tid in $FEATURES" \
          2>/dev/null | grep -o 'agent:[^ ]*' | head -1 || echo "")
        [ -n "$agent_id" ] && AGENT_IDS+=("$agent_id")
      done

      # Poll until all wave agents finish
      for agent_id in "${AGENT_IDS[@]}"; do
        while claude agents --json 2>/dev/null | python3 -c "
import json,sys
agents=json.load(sys.stdin)
a=next((a for a in agents if a.get('id')=='$agent_id'),None)
sys.exit(0 if a and a.get('status') in ('running','pending') else 1)" 2>/dev/null; do
          sleep 10
        done
      done
    else
      # Sequential fallback (wave has 1 task, or --parallel-waves not set)
      while [ "$iter" -lt "$max_iter" ]; do
        iter=$((iter+1))
        wave_pending=$(python3 -c "
import json
d=json.load(open('$FEATURES'))
print(len([t for t in d['tasks'] if t.get('wave',1)==$wave and t['status'] in ('pending','in_progress')]))" 2>/dev/null || echo 0)
        [ "$wave_pending" -eq 0 ] && break

        claude \
          --permission-mode auto \
          --max-turns <MAX_TURNS_WORKER> \
          --max-budget-usd <MAX_BUDGET_USD> \
          --effort high \
          --allowedTools "Read,Edit,Bash,Glob,Grep" \
          -p "Read <HARNESS_SLUG>-session-init.md, then execute the next pending task in wave $wave of $FEATURES" \
          >> "$LOG" 2>&1

        if [ "$WITH_QA" -eq 1 ]; then
          echo "[$(date '+%Y-%m-%d %H:%M %Z')] QA evaluator..." >> "$LOG"
          claude \
            --permission-mode auto \
            --max-turns 10 \
            --effort high \
            -p "Use the <HARNESS_SLUG>-qa agent to evaluate the most recently completed task in $FEATURES" \
            >> "$LOG" 2>&1
        fi
      done
    fi
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] Wave $wave complete." >> "$LOG"
  done

  pending=$(python3 -c "
import json
d=json.load(open('$FEATURES'))
print(len([t for t in d['tasks'] if t['status'] in ('pending','in_progress')]))" 2>/dev/null || echo -1)
  if [ "$pending" -gt 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] WARNING: $pending tasks still pending after all waves." >> "$LOG"
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

## Phase 7 — Register in manifest (if present)

If `harness-manifest.json` exists, read it and append to a `harnesses` array (create the
array if the manifest lacks one):
```json
{
  "slug": "<HARNESS_SLUG>",
  "name": "<HARNESS_NAME>",
  "features_file": "<HARNESS_SLUG>-features.json",
  "session_init": "<HARNESS_SLUG>-session-init.md",
  "created_at": "<LOCAL_TIMESTAMP>"
}
```
Write it back.

If `harness-manifest.json` does **not** exist — a self-hosted source repo, or a project set
up without `/claude-warp-setup` — **skip registration** (the harness is fully functional
without it). Do not create a manifest here; print
`no harness-manifest.json — skipped registry`.

## Phase 8 — Commit

```bash
# Base files always committed
git add .claude/agents/<HARNESS_SLUG>-initializer.md \
        <HARNESS_SLUG>-features.json \
        <HARNESS_SLUG>-session-init.md \
        VISION.md AGENTS.md PROMPT.md \
        scripts/run-<HARNESS_SLUG>.sh
git add harness-manifest.json 2>/dev/null || true   # only if the registry exists

# Add QA agent if --with-qa was used
# git add .claude/agents/<HARNESS_SLUG>-qa.md

git commit -m "feat(harness): scaffold <HARNESS_SLUG>"
```

## Phase 9 — Report

```
Harness scaffolded ✓

  Initializer : .claude/agents/<HARNESS_SLUG>-initializer.md
  Feature list: <HARNESS_SLUG>-features.json
  Session init: <HARNESS_SLUG>-session-init.md
  Anchor files: VISION.md, AGENTS.md, PROMPT.md
  Runner      : scripts/run-<HARNESS_SLUG>.sh
  QA agent    : .claude/agents/<HARNESS_SLUG>-qa.md  ← if --with-qa

To run:
  bash scripts/run-<HARNESS_SLUG>.sh                          # standard (sequential)
  bash scripts/run-<HARNESS_SLUG>.sh --parallel-waves         # parallel within each wave
  bash scripts/run-<HARNESS_SLUG>.sh --retry                  # Inner/Outer Dual Loop on stall
  bash scripts/run-<HARNESS_SLUG>.sh --with-qa                # QA evaluator after each task
  bash scripts/run-<HARNESS_SLUG>.sh --parallel-waves --with-qa  # parallel + QA

The runner will:
  1. Invoke the initializer once to populate the task list with wave assignments
  2. Execute waves in order (wave 1 → wave 2 → ...); tasks in the same wave run
     in parallel (--parallel-waves) or sequentially (default)
  3. On --with-qa: invoke the QA evaluator after each task; task reverts to
     pending if QA fails, with feedback written back into features.json
  4. On --retry: if stalled, re-invoke the initializer with failure context

Budget cap   : $<MAX_BUDGET_USD> per coding-agent invocation
Verification : <VERIFICATION_CMD>

Optional DOER/CHECKER — add an independent reviewer:
  claude -p '/claude-warp-new-agent "checker for <HARNESS_SLUG>: \
    reviews completed tasks for correctness before the next task starts"'
```
