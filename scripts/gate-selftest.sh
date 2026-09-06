#!/usr/bin/env bash
# ClaudeWarp gate self-test — proves `scripts/dev.sh verify` can still REPORT a failure.
#
# Why this exists: nine separate times in this repo's history the checking instrument was the
# broken thing, not the artifact. The worst instance was the gate itself — `verify()` called every
# check bare under `set -euo pipefail`, and six checks ended in `[ "$FAIL" -eq 0 ] && note_ok …`,
# an AND-list that returns 1 when the tally is non-zero. So the first failing check killed the run:
# one planted failure reached 7 of 14 checks and printed NO verdict banner at all. `verify` could
# not say "VERIFY FAILED". Every green run in this repo's history was green only because nothing
# had ever failed.
#
# A gate that cannot report failure is not a gate, and no amount of re-reading it reveals that —
# only mutating the artifact under it does. This script is that mutation, made permanent.
#
# It plants known failures in a throwaway copy of the WORKING TREE (not HEAD — uncommitted fixes
# must be under test) and asserts the gate names them. Deterministic: no tokens, no network.
#
# Usage: bash scripts/gate-selftest.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
FAIL=0
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

# Mirror the WORKING TREE, so a fix that is not yet committed is the thing being tested.
# `git archive HEAD` would silently test the previous commit instead — the exact class of
# instrument bug this script exists to catch.
git ls-files -z | while IFS= read -r -d '' f; do
  mkdir -p "$SANDBOX/$(dirname "$f")"
  cp "$f" "$SANDBOX/$f"
done
[ -f "$SANDBOX/scripts/dev.sh" ] || { echo "FATAL: sandbox mirror failed"; exit 2; }

# Run the gate in the sandbox; echo the BARE exit status (never through a pipe — `cmd | tail`
# reports tail's status, which is how a failing checker last read as green here).
run_gate() {
  ( cd "$SANDBOX" && bash scripts/dev.sh verify > "$SANDBOX/out.txt" 2>&1; echo $? )
}
checks_reached() { grep -c '^\[' "$SANDBOX/out.txt" 2>/dev/null || echo 0; }

echo "ClaudeWarp gate self-test — can \`dev.sh verify\` report a failure?"
echo

# ── 1. Baseline: the unmutated tree must pass, all 14 checks, exit 0 ────────────────────────
echo "[1/5] Baseline — clean tree passes"
rc="$(run_gate)"
n="$(checks_reached)"
[ "$rc" = "0" ] || fail "clean tree: expected exit 0, got $rc"
[ "$n" = "14" ] || fail "clean tree: expected 14 checks, got $n"
grep -q 'VERIFY PASSED' "$SANDBOX/out.txt" || fail "clean tree: no 'VERIFY PASSED' banner"
[ "$FAIL" -eq 0 ] && pass "clean tree: 13 checks, VERIFY PASSED, exit 0"

# ── 2. A failure in the FIRST check must not hide the other twelve ─────────────────────────
# This is the load-bearing case. Under the old gate this aborted at check 1.
echo "[2/5] Failure in check 1 — the remaining checks still run, and the banner still prints"
before="$FAIL"
perl -pi -e 's{^name: claude-warp-retro$}{name: DELIBERATELY-WRONG}' "$SANDBOX/skills/claude-warp-retro/SKILL.md"
rc="$(run_gate)"; n="$(checks_reached)"
[ "$rc" = "1" ]  || fail "check-1 failure: expected exit 1, got $rc"
[ "$n" = "14" ]  || fail "check-1 failure: gate stopped after $n of 14 checks (it aborted early)"
grep -q 'VERIFY FAILED' "$SANDBOX/out.txt" || fail "check-1 failure: no 'VERIFY FAILED' banner — the gate cannot report failure"
grep -q '(1 issue(s))'  "$SANDBOX/out.txt" || fail "check-1 failure: issue count is not 1"
# A later check that PASSED must still print its ✓ — the tally is per-check, not global.
grep -q 'all skills documented' "$SANDBOX/out.txt" \
  || fail "check-1 failure: a later PASSING check printed no ✓ (pass reporting reads a global counter)"
perl -pi -e 's{^name: DELIBERATELY-WRONG$}{name: claude-warp-retro}' "$SANDBOX/skills/claude-warp-retro/SKILL.md"
[ "$FAIL" -eq "$before" ] && pass "check-1 failure: 13 checks, VERIFY FAILED (1 issue), exit 1, later ✓ intact"

# ── 3. Two independent failures must be counted as two ─────────────────────────────────────
echo "[3/5] Two failures — counted independently"
before="$FAIL"
perl -pi -e 's{5/6}{4/6}g' "$SANDBOX/docs/reference/architecture.md"
perl -pi -e 's{^name: claude-warp-ledger$}{name: ALSO-WRONG}' "$SANDBOX/skills/claude-warp-ledger/SKILL.md"
rc="$(run_gate)"; n="$(checks_reached)"
[ "$rc" = "1" ] || fail "two failures: expected exit 1, got $rc"
[ "$n" = "14" ] || fail "two failures: gate stopped after $n of 14 checks"
grep -q '(2 issue(s))' "$SANDBOX/out.txt" || fail "two failures: issue count is not 2 — failures are not tallied independently"
perl -pi -e 's{4/6}{5/6}g' "$SANDBOX/docs/reference/architecture.md"
perl -pi -e 's{^name: ALSO-WRONG$}{name: claude-warp-ledger}' "$SANDBOX/skills/claude-warp-ledger/SKILL.md"
[ "$FAIL" -eq "$before" ] && pass "two failures: VERIFY FAILED (2 issue(s)), 13 checks, exit 1"

# ── 4. The --live branch must COUNT its own failure, not print a bare ✗ and die ─────────────
# Its two early-exit paths printed "  ✗ …" directly and `return 1`, which tripped errexit at the
# call site: the run died before the banner, so a broken live gate looked like a crash.
echo "[4/5] --live with no \`claude\` on PATH — a counted failure, not an abort"
before="$FAIL"
rc="$( cd "$SANDBOX" && PATH=/usr/bin:/bin bash scripts/dev.sh verify --live > "$SANDBOX/live.txt" 2>&1; echo $? )"
[ "$rc" = "1" ] || fail "--live: expected exit 1, got $rc"
grep -q 'VERIFY FAILED' "$SANDBOX/live.txt" || fail "--live: no 'VERIFY FAILED' banner — the live branch aborts instead of reporting"
grep -q 'not on PATH'   "$SANDBOX/live.txt" || fail "--live: missing the diagnostic naming the cause"
[ "$FAIL" -eq "$before" ] && pass "--live: counted failure, VERIFY FAILED, exit 1"

# ── 5. A check that CRASHES must still produce a verdict line ──────────────────────────────
# errexit is deliberately live inside check bodies, so a bug in a check can abort the run. That
# must never look like silence: it is indistinguishable from "the gate never ran".
echo "[5/5] A crashing check — the run still says something"
before="$FAIL"
perl -0pi -e 's{(echo "\[1/14\] Source integrity[^\n]*\n  check_begin\n)}{$1  ( exit 3 )\n}' "$SANDBOX/scripts/dev.sh"
grep -q '( exit 3 )' "$SANDBOX/scripts/dev.sh" || fail "crash case: could not plant the crash (dev.sh check-1 preamble moved)"
rc="$(run_gate)"
[ "$rc" != "0" ] || fail "crash case: a crashing check returned exit 0"
grep -q 'VERIFY CRASHED' "$SANDBOX/out.txt" \
  || fail "crash case: no 'VERIFY CRASHED' line — the gate ends silently when a check aborts"
perl -0pi -e 's{\n  \( exit 3 \)}{}' "$SANDBOX/scripts/dev.sh"
[ "$FAIL" -eq "$before" ] && pass "crashing check: VERIFY CRASHED reported, non-zero exit"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "GATE SELF-TEST PASSED ✓  — dev.sh verify can report failure"
  exit 0
else
  echo "GATE SELF-TEST FAILED ✗  ($FAIL issue(s)) — the gate cannot be trusted to report failure"
  exit 1
fi
