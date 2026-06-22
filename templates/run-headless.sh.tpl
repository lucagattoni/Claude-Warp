#!/usr/bin/env bash
# Headless runner for loop: {{SKILL_NAME}}
# Run by cron / launchd / CI. Logs to logs/{{SKILL_SLUG}}-YYYYMMDD.log
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

mkdir -p logs
LOG="logs/{{SKILL_SLUG}}-$(date '+%Y%m%d').log"

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Starting {{SKILL_NAME}}" >> "$LOG"

claude \
  --permission-mode auto \
  --max-turns {{MAX_TURNS}} \
  --max-budget-usd {{MAX_BUDGET_USD}} \
  --allowedTools "{{ALLOWED_TOOLS}}" \
  -p "/{{SKILL_SLUG}}" \
  >> "$LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Done" >> "$LOG"
