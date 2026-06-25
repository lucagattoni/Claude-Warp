#!/usr/bin/env bash
# Headless runner for loop: {{SKILL_NAME}}
# Run by cron / launchd / CI. Logs to logs/{{SKILL_SLUG}}-YYYYMMDD.log
# Usage: bash scripts/run-{{SKILL_SLUG}}.sh [--max-minutes N]
#   --max-minutes N  Wall-clock timeout in minutes (default: 60).
#                    Prevents runaway overnight sessions when budget or turn
#                    cap alone would allow the loop to run indefinitely.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

MAX_MINUTES=60
for arg in "$@"; do
  [[ "$arg" == "--max-minutes" ]] && { shift; MAX_MINUTES="${1:-60}"; }
done

mkdir -p logs
LOG="logs/{{SKILL_SLUG}}-$(date '+%Y%m%d').log"

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Starting {{SKILL_NAME}} (max ${MAX_MINUTES}m)" >> "$LOG"

timeout "${MAX_MINUTES}m" claude \
  --permission-mode auto \
  --max-turns {{MAX_TURNS}} \
  --max-budget-usd {{MAX_BUDGET_USD}} \
  --effort high \
  --allowedTools "{{ALLOWED_TOOLS}}" \
  -p "/{{SKILL_SLUG}}" \
  >> "$LOG" 2>&1
RC=$?

if [ "$RC" -eq 124 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] TIMEOUT: loop exceeded ${MAX_MINUTES}m wall-clock limit — verdict: timeout" >> "$LOG"
  exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Done (exit $RC)" >> "$LOG"
exit "$RC"
