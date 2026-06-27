#!/usr/bin/env bash
# check-ai-residuals.sh — scan changed files for AI fake-done residuals.
#
# Closes the two commonest fake-done modes: a verifier that always passes
# (expect(true).toBe(true)), and a "done" task that left scaffolding behind.
#
# Risk-scaled, per ClaudeWarp's R0-R5 doctrine:
#   R0-R1 -> advisory  (report, exit 0)
#   R2+   -> blocking  (HIGH-confidence residual in changed files -> exit 1)
#
# Usage:
#   scripts/check-ai-residuals.sh [--risk R0|R1|R2|R3|R4|R5] [path ...]
#   scripts/check-ai-residuals.sh --self-test
#
# With no paths, scans files changed vs HEAD (staged + unstaged). HIGH-confidence
# patterns are near-certain fake-done; MEDIUM patterns are always advisory.
set -uo pipefail

RISK="R2"          # default to the safe (blocking) side
SELF_TEST=0
PATHS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --risk) RISK="${2:-R2}"; shift 2 ;;
    --risk=*) RISK="${1#--risk=}"; shift ;;
    --self-test) SELF_TEST=1; shift ;;
    -h|--help) grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done

# HIGH-confidence: near-certain fake-done / disabled verification.
HIGH='expect\(true\)\.toBe\(true\)|expect\(1\)\.toBe\(1\)|assert True\b|\bit\.skip\(|\btest\.skip\(|\bdescribe\.skip\(|\bxit\(|\bxdescribe\(|@pytest\.mark\.skip|throw new Error\(["'"'"']not implemented|TODO: ?implement|FIXME: ?(broken|stub)'
# MEDIUM-confidence: smells worth a human glance, never blocking on their own.
MEDIUM='\bTODO\b|\bFIXME\b|\bmockData\b|\bdummyData\b|\bplaceholder\b|console\.log\(|\blocalhost\b'

# is_blocking RISK -> 0 (yes) for R2..R5, 1 (no) for R0/R1
is_blocking() {
  case "$1" in
    R2|R3|R4|R5) return 0 ;;
    *) return 1 ;;
  esac
}

# Resolve the file list to scan.
resolve_paths() {
  if [ "${#PATHS[@]}" -gt 0 ]; then
    printf '%s\n' "${PATHS[@]}"
  else
    { git diff --name-only HEAD 2>/dev/null; git diff --name-only --staged 2>/dev/null; } | sort -u
  fi
}

scan() {
  local high_hits=0 med_hits=0 f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ -f "$f" ] || continue
    # skip this scanner itself (it defines the patterns it scans for)
    case "$f" in scripts/check-ai-residuals.sh) continue ;; esac
    # HIGH patterns are code constructs (faked tests, disabled verifiers); documentation
    # legitimately quotes them while describing tooling, so skip HIGH for markdown/text.
    scan_high=1
    case "$f" in *.md|*.markdown|*.txt) scan_high=0 ;; esac
    if [ "$scan_high" -eq 1 ] && grep -nIE "$HIGH" "$f" 2>/dev/null | sed "s#^#  HIGH  $f:#"; then
      high_hits=$((high_hits + $(grep -cIE "$HIGH" "$f" 2>/dev/null || echo 0)))
    fi
    if grep -nIE "$MEDIUM" "$f" 2>/dev/null | sed "s#^#  med   $f:#"; then
      med_hits=$((med_hits + $(grep -cIE "$MEDIUM" "$f" 2>/dev/null || echo 0)))
    fi
  done < <(resolve_paths)
  echo "__HIGH=$high_hits __MED=$med_hits"
}

run_scan() {
  local out high med
  out="$(scan)"
  # echo the human-readable hit lines (everything except the trailer)
  echo "$out" | grep -v '^__HIGH=' || true
  high="$(echo "$out" | sed -n 's/.*__HIGH=\([0-9]*\).*/\1/p' | tail -1)"
  med="$(echo "$out" | sed -n 's/.*__MED=\([0-9]*\).*/\1/p' | tail -1)"
  high="${high:-0}"; med="${med:-0}"

  echo "residuals: HIGH=$high MEDIUM=$med  (risk=$RISK)"
  if [ "$high" -gt 0 ] && is_blocking "$RISK"; then
    echo "BLOCK: $high high-confidence residual(s) in changed files at $RISK — not done."
    return 1
  fi
  if [ "$high" -gt 0 ]; then
    echo "ADVISORY: $high high-confidence residual(s) — review (advisory at $RISK)."
  fi
  return 0
}

self_test() {
  local tmp rc pass=1
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  printf 'test("x", () => { expect(true).toBe(true); });\n' > "$tmp/fake.test.js"
  printf 'export const add = (a, b) => a + b;\n' > "$tmp/clean.js"

  # 1. planted residual at R2 must BLOCK (non-zero)
  PATHS=("$tmp/fake.test.js"); RISK="R2"
  run_scan >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] && echo "ok   planted residual blocks at R2" || { echo "FAIL planted residual did not block at R2"; pass=0; }

  # 2. planted residual at R0 must be ADVISORY (zero)
  PATHS=("$tmp/fake.test.js"); RISK="R0"
  run_scan >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] && echo "ok   planted residual advisory at R0" || { echo "FAIL planted residual blocked at R0"; pass=0; }

  # 3. clean file at R2 must PASS (zero)
  PATHS=("$tmp/clean.js"); RISK="R2"
  run_scan >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] && echo "ok   clean file passes at R2" || { echo "FAIL clean file flagged at R2"; pass=0; }

  [ "$pass" -eq 1 ] && { echo "self-test: PASS"; return 0; } || { echo "self-test: FAIL"; return 1; }
}

if [ "$SELF_TEST" -eq 1 ]; then
  self_test; exit $?
fi
run_scan; exit $?
