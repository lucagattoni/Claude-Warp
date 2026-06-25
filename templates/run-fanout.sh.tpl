#!/usr/bin/env bash
# Fan-out runner for: {{SKILL_NAME}}
# Launches one background agent per item using `claude --bg --worktree` for
# native git-isolated parallel execution. No manual worktree or PID management.
# Usage: bash scripts/run-fanout-{{SKILL_SLUG}}.sh [--dry-run] [--max-minutes N]
#   --max-minutes N  Wall-clock timeout in minutes (default: 120). Kills all
#                    remaining agent polls and exits if the total fan-out run
#                    exceeds this duration.
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

mkdir -p logs
RUN_ID="$(date '+%Y%m%d-%H%M%S')"
SUMMARY_LOG="logs/{{SKILL_SLUG}}-${RUN_ID}.log"

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Fan-out start: {{SKILL_NAME}}" | tee -a "$SUMMARY_LOG"

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

# ── Step 2: Launch background agents ─────────────────────────────────────────
# claude --bg --worktree: each agent gets an isolated git worktree, preventing
# concurrent file-write conflicts without manual worktree setup.
# All agents launch immediately; the infrastructure manages concurrency.
SESSION_MAP=()   # entries: "<session-id>|||<item>"

while IFS= read -r item; do
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Launching: ${item}" | tee -a "$SUMMARY_LOG"

  SESSION_ID=$(claude \
    --bg \
    --worktree \
    --max-turns {{MAX_TURNS}} \
    --max-budget-usd {{MAX_BUDGET_USD}} \
    --effort high \
    --permission-mode auto \
    --allowedTools "{{ALLOWED_TOOLS}}" \
    -p "{{TASK_PROMPT_PREFIX}} ${item}" 2>&1 | \
    grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1 || true)

  if [ -z "$SESSION_ID" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] WARN: no session ID captured for: ${item}" | tee -a "$SUMMARY_LOG"
    SESSION_ID="unknown-$(date +%s%N)"
  fi

  SESSION_MAP+=("${SESSION_ID}|||${item}")
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Session ${SESSION_ID}: ${item}" | tee -a "$SUMMARY_LOG"
done < "$TASK_LIST"
rm -f "$TASK_LIST"

echo "[$(date '+%Y-%m-%d %H:%M %Z')] ${#SESSION_MAP[@]} agents running. Monitor: claude agents" | tee -a "$SUMMARY_LOG"

# ── Step 3: Poll until all sessions complete ──────────────────────────────────
PASS=0
FAIL=0
PENDING_MAP=("${SESSION_MAP[@]}")

while [ "${#PENDING_MAP[@]}" -gt 0 ]; do
  AGENTS_JSON=$(claude agents --json 2>/dev/null || echo "[]")
  STILL_RUNNING=()

  for entry in "${PENDING_MAP[@]}"; do
    SESSION_ID="${entry%%|||*}"
    item="${entry##*|||}"
    PREFIX="${SESSION_ID:0:8}"

    STATUS=$(printf '%s' "$AGENTS_JSON" | python3 -c "
import json, sys
agents = json.load(sys.stdin)
match = next((a for a in agents if a.get('id','').startswith('${PREFIX}')), None)
print(match['status'] if match else 'not_found')
" 2>/dev/null || echo "not_found")

    case "$STATUS" in
      completed|done|success|exited)
        echo "[$(date '+%Y-%m-%d %H:%M %Z')] PASS: ${item}" | tee -a "$SUMMARY_LOG"
        PASS=$((PASS+1))
        ;;
      failed|error|cancelled)
        echo "[$(date '+%Y-%m-%d %H:%M %Z')] FAIL: ${item}" | tee -a "$SUMMARY_LOG"
        echo "  Logs: claude logs ${SESSION_ID}" | tee -a "$SUMMARY_LOG"
        FAIL=$((FAIL+1))
        ;;
      not_found)
        echo "[$(date '+%Y-%m-%d %H:%M %Z')] WARN: session ${SESSION_ID} not found — treated as failed" | tee -a "$SUMMARY_LOG"
        FAIL=$((FAIL+1))
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
      echo "[$(date '+%Y-%m-%d %H:%M %Z')] TIMEOUT: fan-out exceeded ${MAX_MINUTES}m — ${#PENDING_MAP[@]} agents still running" | tee -a "$SUMMARY_LOG"
      FAIL=$((FAIL + ${#PENDING_MAP[@]}))
      break
    fi
    sleep 15
  fi
done

# ── Step 4: Summary ───────────────────────────────────────────────────────────
echo "" | tee -a "$SUMMARY_LOG"
echo "[$(date '+%Y-%m-%d %H:%M %Z')] Fan-out complete: {{SKILL_NAME}}" | tee -a "$SUMMARY_LOG"
echo "  Total : ${TOTAL}" | tee -a "$SUMMARY_LOG"
echo "  Pass  : ${PASS}"  | tee -a "$SUMMARY_LOG"
echo "  Fail  : ${FAIL}"  | tee -a "$SUMMARY_LOG"
echo "  Sessions: claude agents" | tee -a "$SUMMARY_LOG"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
