#!/usr/bin/env bash
# Builds a MULTI-RUN loop-state fixture (RETRO_FIXTURE_LOG.md, 12 runs, all six verdicts,
# a stagnation-triggered handoff, a fix-commit, and an invisible guard-fired skip) with
# matching git commits, in a throwaway repo. Zero LLM tokens spent — pure shell.
#
# Usage: bash build.sh /path/to/scratch-dir
set -euo pipefail
DEST="${1:?usage: build.sh <scratch-dir>}"
SLUG="retro-fixture-loop"
STATE="RETRO_FIXTURE_LOG.md"
HERE="$(cd "$(dirname "$0")" && pwd)"

rm -rf "$DEST"
mkdir -p "$DEST/.claude/skills/$SLUG" "$DEST/logs"
cd "$DEST"
git init -q
git config user.email "fixture@example.com"
git config user.name "Retro Fixture"

# Minimal skill file so the slug-glob pathspec has a real "loop logic file" to match.
cat > ".claude/skills/$SLUG/SKILL.md" <<'EOF'
---
name: retro-fixture-loop
description: Fixture loop for exercising /claude-warp-retro against multi-run history.
---
Fixture loop body (not a real loop; used only to build retro test history).
EOF
git add ".claude/skills/$SLUG/SKILL.md"
git commit -q -m "feat(${SLUG}): scaffold fixture loop"

commit_run() {  # commit_run <YYYY-MM-DD> <section-text-file>
  local date="$1" file="$2"
  cat "$file" >> "$STATE"
  git add "$STATE"
  GIT_AUTHOR_DATE="$date 09:00:00" GIT_COMMITTER_DATE="$date 09:00:00" \
    git commit -q -m "loop(${SLUG}): run ${date}"
}

# ---- header (updated in place after every run; git tracks the final value) ----
write_header() {
  cat > "$STATE" <<EOF
<!-- state:
last_run: $1
last_verdict: $2
runs_total: $3
consecutive_fails: $4
consecutive_stagnation: $5
acting_on: null
-->

EOF
}

write_header "2026-08-01 09:00 UTC" "stopped" 0 0 0   # placeholder, rewritten each run below
BODY="$DEST/.body.tmp"

append_and_commit() { # append_and_commit <date> <time> <verdict> <body...> ; then rewrite header via caller
  local date="$1" time="$2" verdict="$3"; shift 3
  {
    echo "## ${date} ${time} UTC — ${verdict}"
    printf '%s\n' "$@"
    echo "---"
    echo
  } >> "$STATE"
}

# We rebuild the whole file fresh each step (header + accumulated body) so the header
# always reflects the state AFTER that run — exactly what Phase 4 does in the real loop.
BODYFILE="$DEST/.body.md"
: > "$BODYFILE"

step() { # step <date> <time> <verdict> <last_run> <cf> <cs> <body-line...>
  local date="$1" time="$2" verdict="$3" cf="$5" cs="$6"; shift 6
  {
    echo "## ${date} ${time} UTC — ${verdict}"
    printf '%s\n' "$@"
    echo "---"
    echo
  } >> "$BODYFILE"
  {
    printf '<!-- state:\nlast_run: %s %s UTC\nlast_verdict: %s\nruns_total: %s\nconsecutive_fails: %s\nconsecutive_stagnation: %s\nacting_on: null\n-->\n\n' \
      "$date" "$time" "$verdict" "$RUNS_TOTAL" "$cf" "$cs"
    cat "$BODYFILE"
  } > "$STATE"
  git add "$STATE"
  GIT_AUTHOR_DATE="$date $time:00" GIT_COMMITTER_DATE="$date $time:00" \
    git commit -q -m "loop(${SLUG}): run ${date}"
}

RUNS_TOTAL=1
step 2026-08-01 09:00 stopped x 1 1 \
  "stopped — investigate before retrying: attempted \`git push --force\` while tidying a stray branch in SCOPE; DISALLOWED_TOOLS blocked it (permission gate fired as designed)."

RUNS_TOTAL=2
step 2026-08-02 09:00 fail x 2 2 \
  "FAILED: \`npm test\` — 3 failing specs in the auth module (session-expiry fixture flake, unrelated to this run's change)."

RUNS_TOTAL=3
step 2026-08-03 09:00 pass x 0 0 \
  "Fixed the 3 failing auth specs (stale fixture timestamp). \`npm test\` 42/42. Committed src/auth/session.test.ts."

RUNS_TOTAL=4
step 2026-08-04 09:00 fail x 1 1 \
  "FAILED: lint check timed out fetching the remote eslint config — no proxy reachable from the cron environment."

RUNS_TOTAL=5
step 2026-08-04 15:40 fail x 2 2 \
  "FAILED again on retry: same lint timeout. Root cause identified (HTTPS_PROXY unset in the cron environment) but not fixed this run."

# FIX_COMMIT: a loop-logic edit interleaved between runs (Phase 2's other bucket).
sed -i.bak 's/Fixture loop body.*/Fixture loop body. Phase 3: set HTTPS_PROXY before invoking lint (see 2026-08-04 timeouts)./' \
  ".claude/skills/$SLUG/SKILL.md" && rm -f ".claude/skills/$SLUG/SKILL.md.bak"
git add ".claude/skills/$SLUG/SKILL.md"
GIT_AUTHOR_DATE="2026-08-04 16:00:00" GIT_COMMITTER_DATE="2026-08-04 16:00:00" \
  git commit -q -m "fix(${SLUG}): document HTTPS_PROXY requirement in Phase 3"

RUNS_TOTAL=6
step 2026-08-05 09:00 pass x 0 0 \
  "Set HTTPS_PROXY in the cron environment (documented in SKILL.md Phase 3). Lint + tests green."

RUNS_TOTAL=7
step 2026-08-06 09:00 timeout x 1 1 \
  "timeout — resume next run: --max-turns cap hit mid-refactor of the reporting module; no partial commit (change had no safe stopping point)."

RUNS_TOTAL=8
step 2026-08-07 09:00 skip x 0 2 \
  "nothing to do — Phase 2.5 found no new items in SCOPE this run."

# ---- INVISIBLE EVENT: a second same-day trigger is blocked by the guard. -----------------
# COMPLETING_VERDICTS="pass skip" (guard.sh.tpl) means last_verdict=skip on 2026-08-07 blocks
# any further run that day. This event writes NOTHING to $STATE and creates NO commit — its
# only trace is stderr, captured here into the gitignored logs/ dir exactly as the real
# runner would (run-headless.sh.tpl's guard check never touches the state file on a block).
cat > "logs/${SLUG}-20260807.log" <<'EOF'
[2026-08-07 09:20:03 UTC] Starting retro-fixture-loop (attempt 1/3, max 60m)
[guard] retro-fixture-loop already completed on 2026-08-07 (verdict: skip) — skipping.
EOF
echo "logs/" > .gitignore
git add .gitignore
git commit -q -m "chore: gitignore logs/" --allow-empty-message -m "logs/ is runtime-local, matches ClaudeWarp convention" >/dev/null 2>&1 || \
  git commit -q -m "chore: gitignore logs/"
# Note: logs/${SLUG}-20260807.log is intentionally NEVER committed — it is the point.

RUNS_TOTAL=9
step 2026-08-08 09:00 pass x 0 0 \
  "Resumed the reporting-module refactor from 2026-08-06; completed and merged. Tests green."

RUNS_TOTAL=10
step 2026-08-09 09:00 pass x 0 1 \
  "No new items in SCOPE; re-ran existing checks as a confidence pass. No file changes."

RUNS_TOTAL=11
step 2026-08-10 09:00 pass x 0 2 \
  "Same as 2026-08-09 — nothing new to do, checks re-confirmed green. No file changes."

RUNS_TOTAL=12
step 2026-08-11 09:00 handoff x 0 3 \
  "3 consecutive runs produced no file changes — loop may be stale or scope has nothing to do." \
  "NEEDS_REVIEW: confirm whether this loop's SCOPE is exhausted or the source feed has gone quiet."

# ── A SIBLING LOOP in the same repo. The loop template explicitly anticipates several loops per
# repo, and retro's original git query used a pathspec UNION ('*<slug>*' '*_LOG.md' '*-STATE.md'),
# which pulls this loop's commits into the other loop's retrospective. Without this sibling the
# pollution case cannot be reproduced and the scoped-pathspec fix cannot be shown to matter.
printf 'other\n' > "$DEST/OTHER_LOOP_LOG.md"
git -C "$DEST" add OTHER_LOOP_LOG.md
GIT_AUTHOR_DATE="2026-08-09T09:05:00Z" GIT_COMMITTER_DATE="2026-08-09T09:05:00Z" \
  git -C "$DEST" -c user.email=f@x -c user.name=fixture \
  commit -q -m "loop(other-loop): run 2026-08-09"

rm -f "$BODYFILE"
echo "Fixture built at: $DEST"
echo "State file: $DEST/$STATE"
echo "Guard-blocked (invisible) event: $DEST/logs/${SLUG}-20260807.log (gitignored, uncommitted)"
git log --oneline
