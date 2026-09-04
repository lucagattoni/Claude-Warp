#!/usr/bin/env bash
# Fan-out runner for: {{SKILL_NAME}}
# Launches one background session per item with `claude --bg --worktree '<task>'` —
# native git-isolated parallel execution: each worker gets its own worktree, no manual
# worktree or PID management. Polls `claude agents --json --all` until every session
# has exited, stops stragglers at the deadline, and writes a summary log.
# Usage: bash scripts/run-fanout-{{SKILL_SLUG}}.sh [--dry-run] [--max-minutes N]
#   --max-minutes N  Wall-clock deadline in minutes (default: 120). Sessions still
#                    running at the deadline are STOPPED (`claude stop`), not left
#                    billing, and counted as timeout.
#
# What binds a background worker, and what does not (verified against Claude Code
# v2.1.261 — not assumed from the flag list):
#   - `--bg` and `-p`/`--print` are rejected together since v2.1.198; the task is the
#     positional argument, placed FIRST so a variadic flag (`--allowedTools <tools...>`)
#     cannot swallow it and `--worktree [name]` cannot take it as the worktree name.
#   - `--max-budget-usd` and `--permission-prompts` only work with `--print`: a background
#     session has NO dollar cap. Its ceilings are `--max-turns`, this runner's deadline, and
#     an explicit `--model` — omit it and the session inherits your interactive default.
#   - Every worker pays a FLOOR COST before it does any work: a fresh session writes its own
#     system prompt + tool definitions into the prompt cache, billed at the model's cache-write
#     rate. Measured on v2.1.261 (session cost-state, one worker, a one-word reply):
#     $0.2425 total, of which $0.2266 (93%) was a 1-hour cache write of 22,659 tokens at Opus 5's
#     2x-base rate. Thinking tokens: 0 — the effort level cost nothing here. So the lever is the
#     MODEL, not the effort: the same write on Sonnet 5 is $0.09. Budget a fan-out as
#     (items x floor) + actual work, and pin the cheapest model that can do the task.
#   - `--disallowedTools` is the hard deny that holds under auto mode; `--allowedTools` is
#     pre-approval the classifier can expand beyond.
#   - Background sessions commit and push their worktree branch when they finish
#     (v2.1.221). Nothing here merges those branches — the operator does.
#   - "Done" below means the SESSION EXITED. Whether the item succeeded is what the loop's
#     own skill records (state file, commit on the worker branch) — never inferred here.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=0
MAX_MINUTES=120
args=("$@")
for i in "${!args[@]}"; do
  [[ "${args[$i]}" == "--dry-run" ]] && DRY_RUN=1
  [[ "${args[$i]}" == "--max-minutes" ]] && MAX_MINUTES="${args[$((i+1))]:-120}"
done

DEADLINE=$(( $(date +%s) + MAX_MINUTES * 60 ))
POLL_SECONDS="${CLAUDEWARP_FANOUT_POLL:-15}"
# Pin the worker model: a background session otherwise inherits your interactive default, and
# the per-worker cache-write floor (see header) scales with the model's price, not the task.
WORKER_MODEL="${CLAUDEWARP_FANOUT_MODEL:-claude-sonnet-5}"
WORKER_EFFORT="${CLAUDEWARP_FANOUT_EFFORT:-high}"

mkdir -p logs
RUN_ID="$(date '+%Y%m%d-%H%M%S')"
SUMMARY_LOG="logs/{{SKILL_SLUG}}-${RUN_ID}.log"

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Fan-out start: {{SKILL_NAME}} (model ${WORKER_MODEL}, effort ${WORKER_EFFORT}, deadline ${MAX_MINUTES}m)" | tee -a "$SUMMARY_LOG"

# ── Step 1: Generate task list ────────────────────────────────────────────────
# Replace this block with your task-list generator.
# Output: one task item per line written to TASK_LIST.
# Examples:
#   find src -name "*.py" > "$TASK_LIST"
#   gh issue list --state open --json number --jq '.[].number' > "$TASK_LIST"
#   claude -p "list all files needing migration, one per line" > "$TASK_LIST"
TASK_LIST="$(mktemp)"
{{TASK_LIST_COMMAND}} > "$TASK_LIST"

TOTAL=$(wc -l < "$TASK_LIST" | tr -d ' ')
echo "[$(date '+%Y-%m-%d %H:%M %Z')] Tasks generated: ${TOTAL}" | tee -a "$SUMMARY_LOG"

if [ "$TOTAL" -eq 0 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] No tasks found — exiting." | tee -a "$SUMMARY_LOG"
  rm -f "$TASK_LIST"
  exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Dry run — task list:" | tee -a "$SUMMARY_LOG"
  cat "$TASK_LIST" | tee -a "$SUMMARY_LOG"
  rm -f "$TASK_LIST"
  exit 0
fi

# ── Step 2: Launch background sessions ───────────────────────────────────────
# `claude --bg` prints `backgrounded · <8-hex id>` — the short id that `claude agents`,
# `attach`, `logs`, `stop` and `rm` all take. Matched without relying on the `·` glyph so a
# C-locale cron environment parses it too.
SESSION_MAP=()   # entries: "<short-id>|||<item>"
LAUNCH_FAIL=0

while IFS= read -r item; do
  [ -n "$item" ] || continue
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Launching: ${item}" | tee -a "$SUMMARY_LOG"

  LAUNCH_OUT=$(claude --bg "{{TASK_PROMPT_PREFIX}} ${item}" \
    --worktree \
    --model "$WORKER_MODEL" \
    --effort "$WORKER_EFFORT" \
    --max-turns {{MAX_TURNS}} \
    --permission-mode auto \
    --disallowedTools "{{DISALLOWED_TOOLS}}" \
    --allowedTools "{{ALLOWED_TOOLS}}" 2>&1) || true
  SESSION_ID=$(printf '%s\n' "$LAUNCH_OUT" | grep -oE 'backgrounded[^0-9a-f]*[0-9a-f]{8}' | grep -oE '[0-9a-f]{8}$' | head -1 || true)

  if [ -z "$SESSION_ID" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] LAUNCH FAILED for: ${item}" | tee -a "$SUMMARY_LOG"
    printf '%s\n' "$LAUNCH_OUT" | sed 's/^/    /' | tee -a "$SUMMARY_LOG"
    LAUNCH_FAIL=$((LAUNCH_FAIL+1))
    continue
  fi

  SESSION_MAP+=("${SESSION_ID}|||${item}")
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Session ${SESSION_ID}: ${item}" | tee -a "$SUMMARY_LOG"
done < "$TASK_LIST"
rm -f "$TASK_LIST"

echo "[$(date '+%Y-%m-%d %H:%M %Z')] ${#SESSION_MAP[@]} sessions running (${LAUNCH_FAIL} failed to launch). Monitor: claude agents" | tee -a "$SUMMARY_LOG"

# ── Step 3: Poll until every session has exited ──────────────────────────────
# `claude agents --json --all` — without `--all` a finished session simply disappears from
# the list, which an earlier version of this runner counted as a failure. Fields that
# matter: `id` (short id), `state` (`working` | `done` | `blocked`), and `waitingFor` (what a
# blocked session is waiting on, e.g. a permission prompt). A `blocked` session is waiting
# for a human who is not there: it is STOPPED and counted as blocked, never waited on.
DONE=0
BLOCKED=0
MISSING=0
TIMEOUT=0
PENDING_MAP=()
[ "${#SESSION_MAP[@]}" -gt 0 ] && PENDING_MAP=("${SESSION_MAP[@]}")

session_state() {   # prints "<state>\t<waitingFor>" for short id $1, or "missing\t"
  python3 -c "
import json, sys
try:
    agents = json.loads(sys.argv[2] or '[]')
except Exception:
    agents = []
a = next((x for x in agents if x.get('id') == sys.argv[1]), None)
if a is None:
    print('missing\t')
else:
    print('%s\t%s' % (a.get('state') or a.get('status') or 'unknown', a.get('waitingFor') or ''))
" "$1" "$2" 2>/dev/null || echo "missing	"
}

while [ "${#PENDING_MAP[@]}" -gt 0 ]; do
  AGENTS_JSON=$(claude agents --json --all 2>/dev/null || echo "[]")
  STILL_RUNNING=()

  for entry in "${PENDING_MAP[@]}"; do
    SESSION_ID="${entry%%|||*}"
    item="${entry##*|||}"
    ROW=$(session_state "$SESSION_ID" "$AGENTS_JSON")
    STATE="${ROW%%	*}"
    WAITING="${ROW#*	}"

    case "$STATE" in
      done)
        echo "[$(date '+%Y-%m-%d %H:%M %Z')] DONE (session exited): ${item}  — verdict: see the loop's state file / branch of session ${SESSION_ID}" | tee -a "$SUMMARY_LOG"
        DONE=$((DONE+1))
        ;;
      blocked)
        echo "[$(date '+%Y-%m-%d %H:%M %Z')] BLOCKED (needs input nobody can give): ${item}  — waiting on: ${WAITING:-unknown}; stopping session ${SESSION_ID}" | tee -a "$SUMMARY_LOG"
        claude stop "$SESSION_ID" >/dev/null 2>&1 || true
        echo "  Logs: claude logs ${SESSION_ID}" | tee -a "$SUMMARY_LOG"
        BLOCKED=$((BLOCKED+1))
        ;;
      missing)
        echo "[$(date '+%Y-%m-%d %H:%M %Z')] MISSING: session ${SESSION_ID} not listed (removed or crashed) — treated as failed: ${item}" | tee -a "$SUMMARY_LOG"
        MISSING=$((MISSING+1))
        ;;
      *)
        STILL_RUNNING+=("$entry")
        ;;
    esac
  done

  PENDING_MAP=()
  [ "${#STILL_RUNNING[@]}" -gt 0 ] && PENDING_MAP=("${STILL_RUNNING[@]}")
  if [ "${#PENDING_MAP[@]}" -gt 0 ]; then
    if [ "$(date +%s)" -ge "$DEADLINE" ]; then
      echo "[$(date '+%Y-%m-%d %H:%M %Z')] TIMEOUT: fan-out exceeded ${MAX_MINUTES}m — stopping ${#PENDING_MAP[@]} still-running session(s)" | tee -a "$SUMMARY_LOG"
      for entry in "${PENDING_MAP[@]}"; do
        SESSION_ID="${entry%%|||*}"
        item="${entry##*|||}"
        claude stop "$SESSION_ID" >/dev/null 2>&1 || true
        echo "  stopped ${SESSION_ID}: ${item}  (claude logs ${SESSION_ID})" | tee -a "$SUMMARY_LOG"
      done
      TIMEOUT=$((TIMEOUT + ${#PENDING_MAP[@]}))
      break
    fi
    sleep "$POLL_SECONDS"
  fi
done

# ── Step 4: Summary ───────────────────────────────────────────────────────────
FAILED=$((LAUNCH_FAIL + BLOCKED + MISSING + TIMEOUT))
echo "" | tee -a "$SUMMARY_LOG"
echo "[$(date '+%Y-%m-%d %H:%M %Z')] Fan-out complete: {{SKILL_NAME}}" | tee -a "$SUMMARY_LOG"
echo "  Total          : ${TOTAL}" | tee -a "$SUMMARY_LOG"
echo "  Done (exited)  : ${DONE}   — not a pass count: read the loop's state file / worker branches" | tee -a "$SUMMARY_LOG"
echo "  Launch failed  : ${LAUNCH_FAIL}" | tee -a "$SUMMARY_LOG"
echo "  Blocked        : ${BLOCKED}" | tee -a "$SUMMARY_LOG"
echo "  Missing        : ${MISSING}" | tee -a "$SUMMARY_LOG"
echo "  Timeout        : ${TIMEOUT}" | tee -a "$SUMMARY_LOG"
echo "  Sessions       : claude agents --all" | tee -a "$SUMMARY_LOG"

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
