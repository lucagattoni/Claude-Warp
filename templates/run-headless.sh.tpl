#!/usr/bin/env bash
# Headless runner for loop: {{SKILL_NAME}}
# Run by cron / launchd / CI. Logs to logs/{{SKILL_SLUG}}-YYYYMMDD.log
# Usage: bash scripts/run-{{SKILL_SLUG}}.sh [--max-minutes N] [--max-retries N]
#   --max-minutes N  Wall-clock timeout PER ATTEMPT in minutes (default: 60).
#                    Prevents runaway overnight sessions when budget or turn
#                    cap alone would allow the loop to run indefinitely.
#   --max-retries N  Retry a transient failure up to N times with exponential
#                    backoff (default: 2) — but ONLY when the failed attempt is
#                    safe to retry (see below). A timeout is never retried.
#
# Safe-to-retry guard (§3.6): a transient drop (API hiccup, network blip) should
# be retried, but a retry is only SAFE if the failed attempt left NO durable trace —
# the working tree is clean AND HEAD is unchanged from before the attempt. If the
# attempt committed or dirtied the tree, retrying could double-apply work, so the
# runner STOPS and surfaces loud instead of looping. On give-up (retries exhausted,
# or unsafe-to-retry) it writes a NOTIFY line and exits non-zero so cron/launchd
# surfaces the failure rather than swallowing it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

MAX_MINUTES=60
MAX_RETRIES=2
ARGS=("$@")
idx=0
while [ "$idx" -lt "${#ARGS[@]}" ]; do
  case "${ARGS[$idx]}" in
    --max-minutes) idx=$((idx+1)); MAX_MINUTES="${ARGS[$idx]:-60}" ;;
    --max-retries) idx=$((idx+1)); MAX_RETRIES="${ARGS[$idx]:-2}" ;;
  esac
  idx=$((idx+1))
done

mkdir -p logs
LOG="logs/{{SKILL_SLUG}}-$(date '+%Y%m%d').log"

run_once() {
  timeout "${MAX_MINUTES}m" claude \
    --permission-mode auto \
    --max-turns {{MAX_TURNS}} \
    --max-budget-usd {{MAX_BUDGET_USD}} \
    --effort high \
    --allowedTools "{{ALLOWED_TOOLS}}" \
    -p "/{{SKILL_SLUG}}" \
    >> "$LOG" 2>&1
}

# Safe to retry only if the working tree is clean AND HEAD is where we left it.
tree_dirty() { [ -n "$(git status --porcelain 2>/dev/null)" ]; }

attempt=0
while : ; do
  HEAD_BEFORE="$(git rev-parse HEAD 2>/dev/null || echo 'no-git')"
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Starting {{SKILL_NAME}} (attempt $((attempt+1))/$((MAX_RETRIES+1)), max ${MAX_MINUTES}m)" >> "$LOG"

  set +e
  run_once
  RC=$?
  set -e

  if [ "$RC" -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] Done (exit 0)" >> "$LOG"
    exit 0
  fi

  if [ "$RC" -eq 124 ]; then
    # A timeout is a wall-clock cap, not a transient drop — do not retry.
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] TIMEOUT: attempt exceeded ${MAX_MINUTES}m wall-clock limit — verdict: timeout (not retried)" >> "$LOG"
    exit 1
  fi

  # Non-zero, non-timeout: candidate transient failure. Gate the retry on safe-to-retry.
  HEAD_AFTER="$(git rev-parse HEAD 2>/dev/null || echo 'no-git')"
  if tree_dirty || [ "$HEAD_BEFORE" != "$HEAD_AFTER" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] NOTIFY: attempt failed (exit $RC) and left a DURABLE TRACE (tree dirty or HEAD moved ${HEAD_BEFORE} -> ${HEAD_AFTER}) — NOT safe to retry; surfacing instead of looping." >> "$LOG"
    exit "$RC"
  fi

  if [ "$attempt" -ge "$MAX_RETRIES" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] NOTIFY: attempt failed (exit $RC); retries exhausted (${MAX_RETRIES}) — giving up." >> "$LOG"
    exit "$RC"
  fi

  attempt=$((attempt+1))
  BACKOFF=$(( 30 * (1 << (attempt-1)) ))   # 30s, 60s, 120s, ...
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] attempt failed (exit $RC); tree clean + HEAD unchanged — safe to retry in ${BACKOFF}s (retry ${attempt}/${MAX_RETRIES})." >> "$LOG"
  sleep "$BACKOFF"
done
