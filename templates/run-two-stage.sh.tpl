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
#
# Stage A cannot escalate into Stage B. A headless session cannot tell whether it
# was launched by this wrapper or by a human, and under `--permission-mode auto`
# the classifier can approve tools that `--allowedTools` never listed — the
# Claude-Loops pipeline this pattern comes from watched its search stage run the
# whole integrate stage inside itself, twice, despite prose telling it to stop.
# What held was a real deny-list: Stage A runs with
# `--disallowedTools "Skill,Bash(git *),Bash(gh *)"` (it may write the artifact;
# it may not invoke skills, commit, push, or open PRs). Defense in depth, at zero
# LLM cost: after Stage A the wrapper checks whether origin/<default-branch>
# already carries this run's Stage B commit (`loop({{STAGE_B_SLUG}}): …`) and
# skips Stage B if so. Both sessions run `--permission-prompts none` (Claude Code
# v2.1.259+; omitted automatically on older CLIs): a prompt nobody can answer is
# denied, never waited on or waved through.
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

# `--permission-prompts none` exists from Claude Code v2.1.259; probe once, pass only when
# supported (${arr[@]+"${arr[@]}"} is the bash-3.2-safe empty-array splice under `set -u`).
PERM_PROMPTS=()
claude --help 2>/dev/null | grep -q -- '--permission-prompts' && PERM_PROMPTS=(--permission-prompts none)

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

# `claude -p "/nope"` prints "Unknown command: /nope" and EXITS 0 (verified on v2.1.261), so a stage
# whose skill is absent would be logged as done. This runner ALWAYS uses a worktree off
# origin/<default-branch>, so a skill committed locally but never pushed is absent here — the single
# most likely way to hit it.
UNKNOWN_CMD_MARKER="Unknown command:"
# Budget exhaustion is a CAP, not a transient drop — the same distinction the exit-124 timeout
# branch already makes. `--max-budget-usd` is per session, so every retry gets a fresh cap and
# fails identically: observed live, a loop scaffolded with $0.25 burned all three attempts and
# ~$0.75 to fail three times. Detected by message because the CLI exits 1, which is generic.
BUDGET_MARKER="Exceeded USD budget"
# A session/usage limit is a wall that lifts at a fixed clock time, not a transient drop, so every
# retry inside the backoff window fails identically. Observed live 2026-09-06: `claude -p` printed
# "You've hit your session limit · resets 3:10am" and exited 1 — the generic retryable code.
# Matched case-insensitively on a punctuation-free substring (the real message carries a
# typographic apostrophe and a U+00B7 middle dot).
SESSION_LIMIT_MARKER="session limit|usage limit"

# run_stage <skill-slug> <disallowed-tools>
run_stage() {
  local slug="$1" deny="$2"
  local f="$WORK_DIR/.claude/skills/${slug}/SKILL.md"
  if [ ! -f "$f" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: $f not found — \`claude -p \"/${slug}\"\` would print 'Unknown command' and exit 0, which this runner would log as a completed stage. This run uses a worktree off origin/${DEFAULT_BRANCH}: has the skill been pushed?" | tee -a "$LOG" >&2
    exit 4
  fi
  local before_bytes; before_bytes=$(wc -c < "$LOG" 2>/dev/null || echo 0)
  ( cd "$WORK_DIR" && ${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} claude \
    --permission-mode auto \
    ${PERM_PROMPTS[@]+"${PERM_PROMPTS[@]}"} \
    --max-turns {{MAX_TURNS}} \
    --max-budget-usd {{MAX_BUDGET_USD}} \
    --effort {{EFFORT}} \
    --allowedTools "{{ALLOWED_TOOLS}}" \
    --disallowedTools "$deny" \
    -p "/${slug}" ) \
    >> "$LOG" 2>&1
  local rc=$?
  if tail -c "+$((before_bytes + 1))" "$LOG" 2>/dev/null | grep -q "$BUDGET_MARKER"; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: the run exhausted its --max-budget-usd cap. Retrying would spend the same amount to fail the same way (each attempt gets a fresh cap), so this is NOT retried. Raise MAX_BUDGET_USD in this script, or narrow the loop's work." | tee -a "$LOG" >&2
    exit 6
  fi
  if tail -c "+$((before_bytes + 1))" "$LOG" 2>/dev/null | grep -qiE "$SESSION_LIMIT_MARKER"; then
    local when; when="$(tail -c "+$((before_bytes + 1))" "$LOG" 2>/dev/null | grep -iE "$SESSION_LIMIT_MARKER" | head -1 | tr -d '\r')"
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: the account hit its session/usage limit — \"${when}\". That is a wall which lifts at a fixed time, not a transient drop, so retrying now would fail identically. NOT retried; reschedule after the stated reset." | tee -a "$LOG" >&2
    exit 7
  fi
  if tail -c "+$((before_bytes + 1))" "$LOG" 2>/dev/null | grep -q "$UNKNOWN_CMD_MARKER"; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] FATAL: the CLI printed '$UNKNOWN_CMD_MARKER' and exited $rc — /${slug} did not resolve in $WORK_DIR. Not retrying; this is deterministic." | tee -a "$LOG" >&2
    exit 4
  fi
  return $rc
}

# True if origin/<default-branch> gained a Stage B commit for THIS loop since base SHA $1
# (the loop skill's commit convention is `loop(<slug>): run <date>`). An unrelated concurrent
# commit does not match, so it is not mistaken for this run's publish.
stage_b_landed() {
  git fetch origin "$DEFAULT_BRANCH" -q
  # ANCHORED to the loop skill's own commit convention (`loop(<slug>): run <date>`) at the START of
  # the subject. An unanchored substring match also fired on a chore commit mentioning the slug, and
  # on git's own `Revert "loop(<slug>): run ..."` — skipping Stage B and exiting 0 on work that
  # never published. The comment above used to claim this; now the code implements it.
  git log --format=%s "$1..origin/${DEFAULT_BRANCH}" 2>/dev/null \
    | grep -qE '^loop\({{STAGE_B_SLUG}}\): run '
}

# run_pipeline <base-sha>
run_pipeline() {
  local base="$1"
  # EXTEND the loop's own deny-list, never replace it: passing only the stage-escalation denies
  # dropped every DO_NOT-derived rule (e.g. Edit(src/**)) and the destructive floor from Stage A,
  # which runs under --permission-mode auto where --allowedTools is not a deny.
  run_stage "{{STAGE_A_SLUG}}" "{{DISALLOWED_TOOLS}},Skill,Bash(git *),Bash(gh *)" || return $?
  echo "[$(date '+%Y-%m-%d %H:%M %Z')] Stage A ({{STAGE_A_SLUG}}) done" >> "$LOG"
  if stage_b_landed "$base"; then
    echo "[$(date '+%Y-%m-%d %H:%M %Z')] NOTIFY: a loop({{STAGE_B_SLUG}}) commit already landed on origin/${DEFAULT_BRANCH} since ${base} — Stage A escalated into Stage B (deny-list breached?) or a concurrent run published. Skipping Stage B; inspect the log." >> "$LOG"
    return 0
  fi
  run_stage "{{STAGE_B_SLUG}}" "{{DISALLOWED_TOOLS}}" || return $?
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
  run_pipeline "$BEFORE"
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
