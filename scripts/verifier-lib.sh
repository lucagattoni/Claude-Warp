#!/usr/bin/env bash
# verifier-lib.sh — shared, markdown-aware matcher for ClaudeWarp verifiers.
#
# Why this exists: the per-PR verifier idiom `has() { grep -qiE "$1" "$2"; }` matches
# raw bytes, so it is blind to markdown structure. Four PRs (v0.17–v0.20) tripped the
# SAME class of false-NEGATIVE — a token the verifier asserted was actually present, but
# grep missed it because markdown had split or decorated it:
#   • PR2: a phrase broken by **bold** decoration
#   • PR3: a phrase spanning a soft-wrapped prose line (two physical lines)
#   • PR4: `target code` soft-wrapped across two lines
#   • (inline `code` spans split a phrase the same way)
# PRs 5–6 only dodged it by hand-anchoring asserts on short single-line tokens.
#
# This library gives verifiers TWO matchers so the author picks per assertion:
#   has    <pat> <file>  — RAW grep (unchanged idiom). Use for structural / line-anchored
#                          patterns: ^name:, ^0\.22\.0$, JSON keys, exact tokens.
#   md_has <pat> <file>  — MARKDOWN-AWARE. Normalizes the file (strip `inline code`,
#                          **bold** and *italic* markers, then join soft-wrapped lines)
#                          before matching. Use for PROSE phrases that markdown may
#                          decorate or wrap.
# Both echo their grep exit code (0 = match) so they drop into `chk "label" "$(...)"`.
#
# Deliberately NOT stripped: `_` (would corrupt snake_case identifiers like
# success_metric / must_not_touch that pervade these docs) and `__` (Python dunders).
# md_has covers backtick + asterisk emphasis and soft-wrap — the cases that actually bit.
# KNOWN GAP: a phrase split by `_italic_` underscore emphasis is therefore missed by md_has too;
# the --self-test asserts this boundary on purpose (anchor on a single token for underscore cases).
#
# Usage:
#   source scripts/verifier-lib.sh        # then use has / md_has / chk in a verifier
#   bash   scripts/verifier-lib.sh --self-test   # prove the matcher fires (fail-closed)
#
# NOT RUN != pass: a match over a missing/empty file yields a non-zero (no-match) rc.

# md_normalize <file> — emit the file as one whitespace-collapsed stream with markdown
# emphasis decoration removed. Missing file => empty output (fail-closed for md_has).
md_normalize() {
  [ -f "$1" ] || return 0
  # strip inline-code backticks, then bold/italic asterisk markers; join all lines;
  # squeeze runs of whitespace to single spaces so soft-wrapped phrases reunite.
  sed -e 's/`//g' -e 's/\*\*//g' -e 's/\*//g' "$1" | tr '\n' ' ' | tr -s '[:space:]' ' '
}

# has <pattern> <file> — raw grep idiom (drop-in; echoes exit code).
has() { grep -qiE "$1" "$2"; echo $?; }

# md_has <pattern> <file> — markdown-aware match (echoes exit code).
md_has() { md_normalize "$2" | grep -qiE "$1" >/dev/null 2>&1; echo $?; }

# chk <label> <rc> — assertion printer; flips VL_PASS=0 on failure.
chk() { if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; VL_PASS=0; fi; }

# ── Self-test ────────────────────────────────────────────────────────────────
verifier_lib_self_test() {
  local tmp; tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  VL_PASS=1

  # Each fixture splits a known phrase the way real markdown did in PRs 2–4.
  printf 'the **alpha** beta gate runs first\n'        > "$tmp/bold.md"      # bold-split (marker between the two words)
  printf 'a phrase that wraps gamma\ndelta across lines\n' > "$tmp/wrap.md"  # soft-wrap split
  printf 'the `epsilon` zeta span is inline\n'         > "$tmp/code.md"      # inline-code split
  printf 'snake_case must_not_touch stays intact\n'    > "$tmp/snake.md"     # underscore safety

  # 1–3: md_has FINDS each phrase that raw grep MISSES (proves the fix + the defect).
  chk "md_has finds **bold**-split phrase"     "$(md_has 'alpha beta' "$tmp/bold.md")"
  chk "raw grep MISSES it (shows the defect)"  "$([ "$(has 'alpha beta' "$tmp/bold.md")" -ne 0 ] && echo 0 || echo 1)"
  chk "md_has finds soft-wrap-split phrase"     "$(md_has 'gamma delta' "$tmp/wrap.md")"
  chk "raw grep MISSES it (shows the defect)"  "$([ "$(has 'gamma delta' "$tmp/wrap.md")" -ne 0 ] && echo 0 || echo 1)"
  chk "md_has finds inline-\`code\`-split phrase" "$(md_has 'epsilon zeta' "$tmp/code.md")"
  chk "raw grep MISSES it (shows the defect)"  "$([ "$(has 'epsilon zeta' "$tmp/code.md")" -ne 0 ] && echo 0 || echo 1)"

  # 4: snake_case / underscores survive normalization (no over-stripping).
  chk "md_has preserves snake_case tokens"      "$(md_has 'must_not_touch' "$tmp/snake.md")"

  # 5: true-negative — md_has does NOT match an absent phrase.
  chk "md_has true-negative (absent phrase)"    "$([ "$(md_has 'this phrase is absent xyz' "$tmp/bold.md")" -ne 0 ] && echo 0 || echo 1)"

  # 6: fail-closed — match over a missing file is non-zero (NOT RUN != pass).
  chk "md_has fails closed on missing file"     "$([ "$(md_has 'anything' "$tmp/does-not-exist.md")" -ne 0 ] && echo 0 || echo 1)"

  # 7: KNOWN GAP (documented limit) — `_italic_` / underscore decoration is deliberately NOT
  # normalized (md_normalize leaves `_` intact for snake_case safety). So a phrase split by
  # underscore-emphasis markers is missed by BOTH raw `has` AND `md_has`. This asserts the
  # boundary on purpose: if a future change starts stripping `_`, these two asserts flip and tell
  # you the contract changed. For an underscore-split phrase, anchor on a single undecorated token.
  printf 'the _alpha_ omega phrase appears here\n' > "$tmp/italic.md"
  chk "KNOWN GAP: raw MISSES _italic_-split"     "$([ "$(has    'alpha omega' "$tmp/italic.md")" -ne 0 ] && echo 0 || echo 1)"
  chk "KNOWN GAP: md_has ALSO misses _italic_"   "$([ "$(md_has 'alpha omega' "$tmp/italic.md")" -ne 0 ] && echo 0 || echo 1)"

  if [ "$VL_PASS" -eq 1 ]; then echo "verifier-lib self-test: PASS"; return 0
  else echo "verifier-lib self-test: FAIL"; return 1; fi
}

# Run the self-test only when executed directly with --self-test (not when sourced).
case "${1:-}" in
  --self-test) verifier_lib_self_test; exit $? ;;
  -h|--help) grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
