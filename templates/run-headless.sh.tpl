#!/usr/bin/env bash
# Headless runner for loop: {{SKILL_NAME}}
# Run by cron / launchd / CI. Logs to logs/{{SKILL_SLUG}}-YYYYMMDD.log
# Usage: bash scripts/run-{{SKILL_SLUG}}.sh [--max-minutes N] [--max-retries N] [--worktree]
#   --max-minutes N  Wall-clock timeout PER ATTEMPT in minutes (default: 60).
#                    Prevents runaway overnight sessions when budget or turn
#                    cap alone would allow the loop to run indefinitely.
#   --max-retries N  Retry a transient failure up to N times with exponential
#                    backoff (default: 2) — but ONLY when the failed attempt is
#                    safe to retry (see below). A timeout is never retried.
#   --worktree       Run the session in a throwaway git worktree branched off
#                     origin/<default-branch> instead of the primary checkout.
#                     Use this for an AUTONOMY_LEVEL L3 loop (writes to production
#                     paths or pushes unattended) — it keeps the cron/launchd run
#                     off the primary checkout's branch/dirty state (§3.6.1).
#
# Safe-to-retry guard (§3.6): a transient drop (API hiccup, network blip) should
# be retried, but a retry is only SAFE if the failed attempt left NO durable trace.
# Without `--worktree`: the working tree is clean AND HEAD is unchanged from before
# the attempt. With `--worktree`: the worktree's local HEAD is disposable per attempt,
# so the durable side effect to check is instead whether origin/<default-branch> has
# advanced past the base SHA — a completed `git push` outlives the worktree, and a
# blind retry after an unconfirmed-but-successful push would double-commit. Either
# way, if the attempt left a durable trace the runner STOPS and surfaces loud instead
# of looping. On give-up (retries exhausted, or unsafe-to-retry) it writes a NOTIFY
# line and exits non-zero so cron/launchd surfaces the failure rather than
# swallowing it.
#
# Reasoning effort ({{EFFORT}}, default `high`): raising effort is a cheaper reliability
# lever than adding another checker pass when reasoning is the bottleneck — a 90-run study
# found high->xhigh lifts first-try-perfect 28%->89% for +9-29% cost, while a bolted-on
# testing tool added 42-68% cost with no reliability gain. Bump to `xhigh` before reaching
# for `--with-qa` on a loop that keeps failing for reasoning reasons, not scope reasons.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

MAX_MINUTES=60
MAX_RETRIES=2
WORKTREE=0
ARGS=("$@")
idx=0
while [ "$idx" -lt "${#ARGS[@]}" ]; do
  case "${ARGS[$idx]}" in
    --max-minutes) idx=$((idx+1)); MAX_MINUTES="${ARGS[$idx]:-60}" ;;
    --max-retries) idx=$((idx+1)); MAX_RETRIES="${ARGS[$idx]:-2}" ;;
    --worktree) WORKTREE=1 ;;
  esac
  idx=$((idx+1))
done

mkdir -p logs
LOG="logs/{{SKILL_SLUG}}-$(date '+%Y%m%d').log"

WORK_DIR="$REPO_ROOT"
DEFAULT_BRANCH=""
WT_BRANCH=""

if [ "$WORKTREE" -eq 1 ]; then
  DEFAULT_BRANCH="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  DEFAULT_BRANCH="${DEFAULT_BRANCH#origin/}"
  DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
  WT_BRANCH="{{SKILL_SLUG}}-$(date '+%Y%m%d-%H%M%S')"
  WORK_DIR="$(mktemp -d)/{{SKILL_SLUG}}-worktree"
  git fetch origin "$DEFAULT_BRANCH" -q
  git worktree add -q -b "$WT_BRANCH" "$WORK_DIR" "origin/${DEFAULT_BRANCH}" >> "$LOG" 2>&1
  cleanup() {
    git worktree remove --force "$WORK_DIR" >> "$LOG" 2>&1 || true
    git branch -D "$WT_BRANCH" >> "$LOG" 2>&1 || true
  }
  trap cleanup EXIT
fi

run_once() {
  ( cd "$WORK_DIR" && timeout "${MAX_MINUTES}m" claude \
    --permission-mode auto \
    --max-turns {{MAX_TURNS}} \
    --max-budget-usd {{MAX_BUDGET_USD}} \
    --effort {{EFFORT}} \
    --allowedTools "{{ALLOWED_TOOLS}}" \
    -p "/{{SKILL_SLUG}}" ) \
    >> "$LOG" 2>&1
}

tree_dirty() { [ -n "$(git -C "$WORK_DIR" status --porcelain 2>/dev/null)" ]; }

# Snapshot the state that determines "did the last attempt leave a durable trace".
snapshot() {
  if [ "$WORKTREE" -eq 1 ]; then
    git fetch origin "$DEFAULT_BRANCH" -q
    git rev-parse "origin/${DEFAULT_BRANCH}" 2>/dev/null || echo 'no-origin'
  else
    git -C "$WORK_DIR" rev-parse HEAD 2>/dev/null || echo 'no-git'
  fi
}

# True if the attempt left a durable trace (not safe to retry).
durable_trace() {
  local before="$1" after="$2"
  if [ "$WORKTREE" -eq 1 ]; then
    [ "$before" != "$after" ]
  else
    tree_dirty || [ "$before" != "$after" ]
  fi
}

attempt=0
while : ; do
  BEFORE="$(snapshot)"
  if [ "$WORKTREE" -eq 1 ]; then
    # Per-attempt tree reset: a prior failed attempt's leftover local commit/dirty
    # state must not carry into the retry (it never left the worktree — origin is
    # the source of truth for what's safe/durable). Reset to origin every attempt.
    git -C "$WORK_DIR" reset --hard "origin/${DEFAULT_BRANCH}" -q
    git -C "$WORK_DIR" clean -fdq
  fi
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Starting {{SKILL_NAME}} (attempt $((attempt+1))/$((MAX_RETRIES+1)), max ${MAX_MINUTES}m$( [ "$WORKTREE" -eq 1 ] && echo ", worktree ${WORK_DIR} off origin/${DEFAULT_BRANCH}" ))" >> "$LOG"

  set +e
  run_once
  RC=$?
  set -e

  if [ "$RC" -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] Done (exit 0)" >> "$LOG"
    if [ "$WORKTREE" -eq 1 ] && [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" = "$DEFAULT_BRANCH" ]; then
      git pull --ff-only >> "$LOG" 2>&1 || true
    fi
    exit 0
  fi

  if [ "$RC" -eq 124 ]; then
    # A timeout is a wall-clock cap, not a transient drop — do not retry.
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] TIMEOUT: attempt exceeded ${MAX_MINUTES}m wall-clock limit — verdict: timeout (not retried)" >> "$LOG"
    exit 1
  fi

  # Non-zero, non-timeout: candidate transient failure. Gate the retry on safe-to-retry.
  AFTER="$(snapshot)"
  if durable_trace "$BEFORE" "$AFTER"; then
    TRACE_DESC="tree dirty or HEAD moved ${BEFORE} -> ${AFTER}"
    [ "$WORKTREE" -eq 1 ] && TRACE_DESC="origin/${DEFAULT_BRANCH} advanced ${BEFORE} -> ${AFTER}"
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] NOTIFY: attempt failed (exit $RC) and left a DURABLE TRACE (${TRACE_DESC}) — NOT safe to retry; surfacing instead of looping." >> "$LOG"
    exit "$RC"
  fi

  if [ "$attempt" -ge "$MAX_RETRIES" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] NOTIFY: attempt failed (exit $RC); retries exhausted (${MAX_RETRIES}) — giving up." >> "$LOG"
    exit "$RC"
  fi

  attempt=$((attempt+1))
  BACKOFF=$(( 30 * (1 << (attempt-1)) ))   # 30s, 60s, 120s, ...
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] attempt failed (exit $RC); safe to retry in ${BACKOFF}s (retry ${attempt}/${MAX_RETRIES})." >> "$LOG"
  sleep "$BACKOFF"
done
