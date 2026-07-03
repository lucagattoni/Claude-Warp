#!/usr/bin/env bash
# Two-stage headless runner for loop: {{SKILL_NAME}}
# Runs Stage A ({{STAGE_A_SLUG}}) and Stage B ({{STAGE_B_SLUG}}) as two separate
# `claude -p` sessions sharing one throwaway git worktree, with an artifact
# handoff at {{ARTIFACT_PATH}} between them. Use this shape when a loop's work
# splits into a noisy retrieval stage and a sequential reasoning/write stage
# that should not share context (the "KB Tracker" pattern).
#
# {{ARTIFACT_PATH}} MUST be gitignored — it is the handoff between stages and
# must survive the worktree's per-attempt reset (plain `git clean -fd`, no
# `-x`, leaves ignored paths alone).
#
# Simplification vs. the source pattern (§3.6.1): this runs BOTH stages inside
# ONE retry loop, not independently. If Stage A already wrote {{ARTIFACT_PATH}}
# on a prior attempt, Stage A's own skill logic should treat a fresh/complete
# artifact as done and skip re-searching — that check lives in the skill, not
# this runner, and is what makes a whole-pipeline retry cheap.
#
# Usage: bash scripts/run-{{SKILL_SLUG}}.sh [--max-minutes N] [--max-retries N]
#   --max-minutes N  Wall-clock timeout PER ATTEMPT (both stages combined),
#                    in minutes (default: 90).
#   --max-retries N  Retry a transient failure up to N times with exponential
#                    backoff (default: 2) — only when safe (see below).
#
# Safe-to-retry guard: same as run-headless.sh.tpl --worktree — the worktree's
# local HEAD is disposable (reset to origin every attempt), so safety is
# judged by whether origin/<default-branch> has advanced past the base SHA.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

MAX_MINUTES=90
MAX_RETRIES=2
ARGS=("$@")
idx=0
while [ "$idx" -lt "${#ARGS[@]}" ]; do
  case "${ARGS[$idx]}" in
    --max-minutes) idx=$((idx+1)); MAX_MINUTES="${ARGS[$idx]:-90}" ;;
    --max-retries) idx=$((idx+1)); MAX_RETRIES="${ARGS[$idx]:-2}" ;;
  esac
  idx=$((idx+1))
done

mkdir -p logs
LOG="logs/{{SKILL_SLUG}}-$(date '+%Y%m%d').log"

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

run_stage() {
  local slug="$1"
  ( cd "$WORK_DIR" && timeout "${MAX_MINUTES}m" claude \
    --permission-mode auto \
    --max-turns {{MAX_TURNS}} \
    --max-budget-usd {{MAX_BUDGET_USD}} \
    --effort {{EFFORT}} \
    --allowedTools "{{ALLOWED_TOOLS}}" \
    -p "/${slug}" ) \
    >> "$LOG" 2>&1
}

run_pipeline() {
  run_stage "{{STAGE_A_SLUG}}" || return $?
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Stage A ({{STAGE_A_SLUG}}) done" >> "$LOG"
  run_stage "{{STAGE_B_SLUG}}" || return $?
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Stage B ({{STAGE_B_SLUG}}) done" >> "$LOG"
}

snapshot() {
  git fetch origin "$DEFAULT_BRANCH" -q
  git rev-parse "origin/${DEFAULT_BRANCH}" 2>/dev/null || echo 'no-origin'
}

attempt=0
while : ; do
  BEFORE="$(snapshot)"
  git -C "$WORK_DIR" reset --hard "origin/${DEFAULT_BRANCH}" -q
  git -C "$WORK_DIR" clean -fdq   # no -x: {{ARTIFACT_PATH}} (gitignored) survives
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Starting {{SKILL_NAME}} pipeline (attempt $((attempt+1))/$((MAX_RETRIES+1)), max ${MAX_MINUTES}m, worktree ${WORK_DIR} off origin/${DEFAULT_BRANCH})" >> "$LOG"

  set +e
  run_pipeline
  RC=$?
  set -e

  if [ "$RC" -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] Done (exit 0)" >> "$LOG"
    if [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" = "$DEFAULT_BRANCH" ]; then
      git pull --ff-only >> "$LOG" 2>&1 || true
    fi
    exit 0
  fi

  if [ "$RC" -eq 124 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] TIMEOUT: attempt exceeded ${MAX_MINUTES}m wall-clock limit — verdict: timeout (not retried)" >> "$LOG"
    exit 1
  fi

  AFTER="$(snapshot)"
  if [ "$BEFORE" != "$AFTER" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] NOTIFY: attempt failed (exit $RC) and origin/${DEFAULT_BRANCH} advanced ${BEFORE} -> ${AFTER} — NOT safe to retry; surfacing instead of looping." >> "$LOG"
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
