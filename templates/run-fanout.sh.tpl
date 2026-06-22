#!/usr/bin/env bash
# Fan-out runner for: {{SKILL_NAME}}
# Generates a task list then executes one claude invocation per item in parallel.
# Usage: bash scripts/run-fanout-{{SKILL_SLUG}}.sh [--dry-run]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

mkdir -p logs
RUN_ID="$(date '+%Y%m%d-%H%M%S')"
LOG_DIR="logs/{{SKILL_SLUG}}-${RUN_ID}"
mkdir -p "$LOG_DIR"
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

# ── Step 2: Fan out ───────────────────────────────────────────────────────────
# MAX_PARALLEL: cap concurrent claude processes to avoid resource exhaustion.
# Tune down for expensive models or large repos; tune up for lightweight tasks.
MAX_PARALLEL={{MAX_PARALLEL}}
PIDS=()
PASS=0
FAIL=0

run_task() {
  local item="$1"
  local item_log="$LOG_DIR/$(echo "$item" | tr '/ :' '___').log"
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] START: ${item}" >> "$item_log"

  claude \
    --permission-mode auto \
    --max-turns {{MAX_TURNS}} \
    --max-budget-usd {{MAX_BUDGET_USD}} \
    --allowedTools "{{ALLOWED_TOOLS}}" \
    -p "{{TASK_PROMPT_PREFIX}} ${item}" \
    >> "$item_log" 2>&1

  local exit_code=$?
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] END (exit ${exit_code}): ${item}" >> "$item_log"
  return $exit_code
}

while IFS= read -r item; do
  # Enforce concurrency cap
  while [ "${#PIDS[@]}" -ge "$MAX_PARALLEL" ]; do
    for i in "${!PIDS[@]}"; do
      if ! kill -0 "${PIDS[$i]}" 2>/dev/null; then
        wait "${PIDS[$i]}" && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
        unset 'PIDS[$i]'
      fi
    done
    PIDS=("${PIDS[@]}")
    sleep 1
  done

  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Dispatching: ${item}" | tee -a "$SUMMARY_LOG"
  run_task "$item" &
  PIDS+=($!)
done < "$TASK_LIST"

# Wait for remaining jobs
for pid in "${PIDS[@]}"; do
  wait "$pid" && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
done

rm -f "$TASK_LIST"

# ── Step 3: Summary ───────────────────────────────────────────────────────────
echo "" | tee -a "$SUMMARY_LOG"
echo "[$(date '+%Y-%m-%d %H:%M %Z')] Fan-out complete: {{SKILL_NAME}}" | tee -a "$SUMMARY_LOG"
echo "  Total : ${TOTAL}" | tee -a "$SUMMARY_LOG"
echo "  Pass  : ${PASS}"  | tee -a "$SUMMARY_LOG"
echo "  Fail  : ${FAIL}"  | tee -a "$SUMMARY_LOG"
echo "  Logs  : ${LOG_DIR}/" | tee -a "$SUMMARY_LOG"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
