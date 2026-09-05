#!/usr/bin/env bash
# Guard for loop: {{SKILL_NAME}}
# Prevents a duplicate run on a day the loop has ALREADY COMPLETED its work.
# Exit 0 = safe to run. Exit 1 = already completed today, skip.
#
# A run that did NOT do the work does not consume the day. Observed live: a run handed off
# (tree dirty outside SCOPE), wrote its dated section honestly, and the guard — which matched
# any "## <today>" header — then blocked the retry for the rest of the day, so the operator
# could resolve the handoff and still not re-run until tomorrow. A handoff/fail/timeout is
# exactly the case where a retry is wanted; only a completing verdict closes the day.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$REPO_ROOT/{{STATE_FILE}}"
TODAY="$(date '+%Y-%m-%d')"

# Verdicts that mean "the day's work is done" — anything else (handoff, fail, timeout, stopped,
# or an unrecognised value) leaves the day open for a retry.
COMPLETING_VERDICTS="pass skip"

if [ -f "$STATE_FILE" ]; then
  # Prefer the machine-readable state header (last_run / last_verdict) over the prose section
  # headers: it states the verdict explicitly instead of inferring it from a heading's wording.
  LAST_RUN="$(sed -n 's/^last_run:[[:space:]]*//p' "$STATE_FILE" | head -1)"
  LAST_VERDICT="$(sed -n 's/^last_verdict:[[:space:]]*//p' "$STATE_FILE" | head -1)"
  case "$LAST_RUN" in
    "$TODAY"*)
      for v in $COMPLETING_VERDICTS; do
        if [ "$LAST_VERDICT" = "$v" ]; then
          echo "[guard] {{SKILL_NAME}} already completed on $TODAY (verdict: $LAST_VERDICT) — skipping." >&2
          exit 1
        fi
      done
      echo "[guard] {{SKILL_NAME}} ran on $TODAY but did not complete (verdict: ${LAST_VERDICT:-unknown}) — clear to retry." >&2
      exit 0
      ;;
  esac
  # No usable state header (older state file): fall back to the dated-section check, which cannot
  # tell a completed run from a handoff — so it is deliberately the conservative path.
  if [ -z "$LAST_RUN" ] && grep -q "^## $TODAY" "$STATE_FILE" 2>/dev/null; then
    echo "[guard] {{SKILL_NAME}} has a section for $TODAY and no state header to judge it — skipping (conservative)." >&2
    exit 1
  fi
fi

# Optional: weekday-only guard (uncomment to enable)
# DAY="$(date '+%u')"  # 1=Mon … 7=Sun
# if [ "$DAY" -ge 6 ]; then
#   echo "[guard] {{SKILL_NAME}} skipped on weekend." >&2
#   exit 1
# fi

echo "[guard] {{SKILL_NAME}} clear to run on $TODAY."
exit 0
