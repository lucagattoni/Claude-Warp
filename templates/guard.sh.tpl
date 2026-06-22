#!/usr/bin/env bash
# Guard for loop: {{SKILL_NAME}}
# Prevents double-execution within the same calendar day (Irish time).
# Exit 0 = safe to run. Exit 1 = already ran today, skip.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$REPO_ROOT/{{STATE_FILE}}"
TODAY="$(TZ='Europe/Dublin' date '+%Y-%m-%d')"

# Check if state file contains a section header for today
if grep -q "^## $TODAY" "$STATE_FILE" 2>/dev/null; then
  echo "[guard] {{SKILL_NAME}} already ran on $TODAY — skipping." >&2
  exit 1
fi

# Optional: weekday-only guard (uncomment to enable)
# DAY="$(TZ='Europe/Dublin' date '+%u')"  # 1=Mon … 7=Sun
# if [ "$DAY" -ge 6 ]; then
#   echo "[guard] {{SKILL_NAME}} skipped on weekend." >&2
#   exit 1
# fi

echo "[guard] {{SKILL_NAME}} clear to run on $TODAY."
exit 0
