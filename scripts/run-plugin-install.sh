#!/usr/bin/env bash
# One-shot goal runner for: Install ClaudeWarp as a Claude Code plugin
# Run once — stops when done conditions are met.
# Resume a partial run by re-invoking; GOAL.md execution log prevents re-doing completed work.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

GOAL_FILE="plugin-install-GOAL.md"
LOG="logs/plugin-install-$(date '+%Y%m%d-%H%M').log"
mkdir -p logs

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Goal start: Install ClaudeWarp as a Claude Code plugin" | tee -a "$LOG"

claude \
  --permission-mode auto \
  --max-turns 30 \
  --max-budget-usd 5 \
  --effort high \
  -p "Read $GOAL_FILE. Complete the goal. Log progress in the Execution log section.
When all Done conditions are checked off, run the verifier:
  claude plugin validate . && test -f .claude-plugin/plugin.json && test -f .claude-plugin/marketplace.json
If the verifier passes, append a final log entry and stop.
If it fails, fix and re-verify. Never mark done until the verifier exits 0." \
  >> "$LOG" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M %Z')] Goal runner exited." | tee -a "$LOG"
