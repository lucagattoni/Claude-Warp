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
#                          **bold**/*italic* asterisk markers AND _italic_ underscore
#                          emphasis, then join soft-wrapped lines) before matching. Use
#                          for PROSE phrases that markdown may decorate or wrap.
# Both echo their grep exit code (0 = match) so they drop into `chk "label" "$(...)"`.
#
# Underscore handling is BOUNDARY-AWARE: a `_` is dropped only as part of a complete
# `_word_` emphasis pair flanked by non-word chars. snake_case (`must_not_touch`),
# leading-underscore identifiers (`_phase`), and `__dunder__` / `mcp__tool__` runs are all
# preserved — only true single-underscore italic emphasis is stripped. (v0.28.1 closed the
# former KNOWN GAP where `_italic_`-split phrases were missed by md_has; the --self-test now
# asserts the gap is CLOSED and that snake_case / leading-underscore / dunders still survive.)
# Residual edge: two ADJACENT emphasis spans (`_a_ _b_`) may strip only the first — rare in
# prose; anchor on a single undecorated token if you ever hit it.
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
  # strip inline-code backticks and **bold**/*italic* asterisk markers; strip _italic_
  # underscore emphasis BOUNDARY-AWARE — only a complete `_word_` pair whose outer sides are
  # non-word chars, so snake_case (`a_b`), leading-underscore (`_phase`) and `__dunder__` runs
  # survive; then join lines and squeeze whitespace so soft-wrapped phrases reunite.
  sed -E \
    -e 's/`//g' \
    -e 's/\*\*//g' \
    -e 's/\*//g' \
    -e 's/(^|[^[:alnum:]_])_([[:alnum:]]([^_]*[[:alnum:]])?)_([^[:alnum:]_]|$)/\1\2\4/g' \
    "$1" | tr '\n' ' ' | tr -s '[:space:]' ' '
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

  # 4b: boundary-aware underscore stripping must NOT corrupt leading-underscore identifiers
  # (e.g. `_phase`, which contract drafts use) or `__dunder__` / `mcp__tool__` runs.
  printf 'the _phase field and mcp__claude__navigate and __init__ stay intact\n' > "$tmp/under.md"
  chk "md_has preserves leading-underscore id"  "$(md_has '_phase field' "$tmp/under.md")"
  chk "md_has preserves dunder/mcp runs"         "$(md_has 'mcp__claude__navigate' "$tmp/under.md")"

  # 5: true-negative — md_has does NOT match an absent phrase.
  chk "md_has true-negative (absent phrase)"    "$([ "$(md_has 'this phrase is absent xyz' "$tmp/bold.md")" -ne 0 ] && echo 0 || echo 1)"

  # 6: fail-closed — match over a missing file is non-zero (NOT RUN != pass).
  chk "md_has fails closed on missing file"     "$([ "$(md_has 'anything' "$tmp/does-not-exist.md")" -ne 0 ] && echo 0 || echo 1)"

  # 7: GAP CLOSED (v0.28.1) — `_italic_` underscore emphasis is now stripped boundary-aware, so a
  # phrase split by underscore-emphasis markers is FOUND by md_has (raw `has` still misses it, since
  # raw grep is unchanged by design). The two asserts below are the inverse of the former KNOWN-GAP
  # pair: md_has must now find it, raw must still miss it.
  printf 'the _alpha_ omega phrase appears here\n' > "$tmp/italic.md"
  chk "raw still MISSES _italic_-split"           "$([ "$(has    'alpha omega' "$tmp/italic.md")" -ne 0 ] && echo 0 || echo 1)"
  chk "md_has NOW finds _italic_-split phrase"    "$(md_has 'alpha omega' "$tmp/italic.md")"

  if [ "$VL_PASS" -eq 1 ]; then echo "verifier-lib self-test: PASS"; return 0
  else echo "verifier-lib self-test: FAIL"; return 1; fi
}

# Run the self-test only when executed directly with --self-test (not when sourced).
case "${1:-}" in
  --self-test) verifier_lib_self_test; exit $? ;;
  -h|--help) grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
