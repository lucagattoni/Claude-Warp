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
#
# Fail-closed permissions (Claude Code v2.1.259+): the session runs `--permission-mode auto`
# with `--permission-prompts none` — anything the auto-mode classifier would have asked a
# human about is DENIED: not waited on (nobody is at the terminal) and not waved through
# (that is what `--dangerously-skip-permissions` does). `--allowedTools` is a pre-approval
# list the classifier may still expand beyond; the hard deny is `--disallowedTools`, which
# holds even under auto mode — keep the destructive set there, not only in a hook. On a
# Claude Code older than v2.1.259 the flag is omitted automatically (see PERM_PROMPTS).
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

# ── Preflight: resolve the `claude` binary ────────────────────────────────────
# cron and launchd run with a minimal PATH (often just /usr/bin:/bin) that does NOT
# include ~/.local/bin, where the native installer puts `claude`. Without this, a
# scheduled run dies at its first invocation with 127 and the loop simply never runs —
# a failure that only appears when you exercise the scaffold the way the scheduler
# does, not when you run it by hand with your own shell. Set CLAUDE_BIN to override.
# CLAUDE_BIN is prepended LAST so it actually wins. Prepending it first and then prepending the
# default install dirs (v0.42.2) let an existing ~/.local/bin/claude silently outrank the override —
# i.e. the one mechanism the FATAL below tells the operator to use was inert exactly when needed.
PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
if [ -n "${CLAUDE_BIN:-}" ]; then
  if [ ! -x "$CLAUDE_BIN" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: CLAUDE_BIN=$CLAUDE_BIN is not an executable file." | tee -a "$LOG" >&2
    exit 127
  fi
  PATH="$(cd "$(dirname "$CLAUDE_BIN")" && pwd):$PATH"
fi
export PATH
if ! command -v claude >/dev/null 2>&1; then
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: \`claude\` not found on PATH ($PATH) — a scheduled run cannot start. Set CLAUDE_BIN=/full/path/to/claude in the cron/launchd environment." | tee -a "$LOG" >&2
  exit 127
fi

# ── Preflight: resolve a wall-clock timeout command ───────────────────────────
# `timeout` is GNU coreutils and is NOT present on stock macOS (Homebrew's coreutils
# installs it as `gtimeout`). Every claude call below was wrapped in it, so on a stock
# Mac the runner failed with exit 127 before ever reaching Claude — and the retry logic
# then read that deterministic failure as a candidate transient one. Resolve it here
# instead, and be honest when it is absent rather than claiming a cap we do not enforce.
TIMEOUT_CMD=()
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout "${MAX_MINUTES}m")
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(gtimeout "${MAX_MINUTES}m")
elif [ "${CLAUDEWARP_REQUIRE_TIMEOUT:-0}" = "1" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: neither \`timeout\` nor \`gtimeout\` found and CLAUDEWARP_REQUIRE_TIMEOUT=1 — refusing to run without the ${MAX_MINUTES}m wall-clock cap. Install it: brew install coreutils" | tee -a "$LOG" >&2
  exit 127
else
  # NOT RUN != pass: say plainly that the cap is unenforced rather than implying it holds.
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] NOTIFY: neither \`timeout\` nor \`gtimeout\` found — the ${MAX_MINUTES}m wall-clock cap is NOT enforced this run (stock macOS ships neither; \`brew install coreutils\` provides gtimeout). --max-turns and --max-budget-usd still bound the run. Set CLAUDEWARP_REQUIRE_TIMEOUT=1 to make this fatal instead (recommended for an L3 loop)." | tee -a "$LOG" >&2
fi

# `--permission-prompts none` exists from Claude Code v2.1.259; older CLIs reject unknown
# flags, so probe once and pass it only when supported. The ${arr[@]+"${arr[@]}"} expansion
# below is the bash-3.2-safe way to splice a possibly-empty array under `set -u`.
PERM_PROMPTS=()
claude --help 2>/dev/null | grep -q -- '--permission-prompts' && PERM_PROMPTS=(--permission-prompts none)

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

# An unresolvable slash command is NOT a failure to the CLI: `claude -p "/nope"` prints
# "Unknown command: /nope" and EXITS 0 (verified on v2.1.261). Without these two guards a scheduled
# loop logs "Done (exit 0)" having executed nothing — the exact failure this harness exists to
# prevent. Guard 1: the skill file must exist in the checkout we are about to run in. That matters
# most under --worktree, which checks out origin/<default-branch>: a skill committed locally but
# never pushed is simply absent there.
assert_skill_present() {
  local f="$WORK_DIR/.claude/skills/{{SKILL_SLUG}}/SKILL.md"
  [ -f "$f" ] && return 0
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: $f not found — \`claude -p \"/{{SKILL_SLUG}}\"\` would print 'Unknown command' and exit 0, which this runner would log as success.$( [ "$WORKTREE" -eq 1 ] && printf '%s' " This run uses --worktree, which checks out origin/${DEFAULT_BRANCH}: has the skill been pushed?" )" | tee -a "$LOG" >&2
  exit 4
}

# Guard 2: even with the file present, catch the marker in the run's own output.
UNKNOWN_CMD_MARKER="Unknown command:"
# Budget exhaustion is a CAP, not a transient drop — the same distinction the exit-124 timeout
# branch already makes. `--max-budget-usd` is per session, so every retry gets a fresh cap and
# fails identically: observed live, a loop scaffolded with $0.25 burned all three attempts and
# ~$0.75 to fail three times. Detected by message because the CLI exits 1, which is generic.
BUDGET_MARKER="Exceeded USD budget"

run_once() {
  assert_skill_present
  local before_bytes; before_bytes=$(wc -c < "$LOG" 2>/dev/null || echo 0)
  ( cd "$WORK_DIR" && ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} claude \
    --permission-mode auto \
    ${PERM_PROMPTS[@]+"${PERM_PROMPTS[@]}"} \
    --max-turns {{MAX_TURNS}} \
    --max-budget-usd {{MAX_BUDGET_USD}} \
    --effort {{EFFORT}} \
    --allowedTools "{{ALLOWED_TOOLS}}" \
    --disallowedTools "{{DISALLOWED_TOOLS}}" \
    -p "/{{SKILL_SLUG}}" ) \
    >> "$LOG" 2>&1
  local rc=$?
  # Only inspect what THIS attempt appended, so a marker from an earlier attempt cannot re-trigger.
  if tail -c "+$((before_bytes + 1))" "$LOG" 2>/dev/null | grep -q "$BUDGET_MARKER"; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: the run exhausted its --max-budget-usd cap. Retrying would spend the same amount to fail the same way (each attempt gets a fresh cap), so this is NOT retried. Raise MAX_BUDGET_USD in this script, or narrow the loop's work." | tee -a "$LOG" >&2
    exit 6
  fi
  if tail -c "+$((before_bytes + 1))" "$LOG" 2>/dev/null | grep -q "$UNKNOWN_CMD_MARKER"; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: the CLI printed '$UNKNOWN_CMD_MARKER' and exited $rc — /{{SKILL_SLUG}} did not resolve in $WORK_DIR. Not retrying; this is deterministic." | tee -a "$LOG" >&2
    exit 4
  fi
  return $rc
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
