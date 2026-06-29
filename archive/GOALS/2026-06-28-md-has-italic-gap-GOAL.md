# Goal: Close the md_has _italic_/soft-wrap gap in verifier-lib.sh

**Slug:** md-has-italic-gap · **Risk:** R2 · **Source:** honesty-riders retro (RETRO.md) improvement #1

## Objective

Make `md_normalize` strip single-underscore `_italic_` emphasis markers in a **boundary-aware** way,
closing the KNOWN GAP that has taxed verifier authors on 4 consecutive PRs (each had to hand-anchor
assertions on single-line tokens to dodge it). Snake_case and `__dunder__`/`mcp__tool__` runs MUST
still survive. Raw `has()` is untouched.

Rule: strip a `_` only when it is **not** flanked by alphanumerics on both sides (emphasis delimiters
have a boundary on at least one side; snake_case underscores have alnum on both).

## Done conditions

- [x] `md_normalize` strips `_italic_` emphasis (boundary-aware) — `_alpha_ omega` → `alpha omega`
- [x] `snake_case` (`must_not_touch`) still preserved by `md_has`
- [x] `__dunder__` / `mcp__tool__` double-underscore runs still preserved (new regression assert)
- [x] `has()` raw matcher unchanged
- [x] The two KNOWN-GAP self-test asserts flipped to expect md_has now finds the underscore-split phrase
- [x] Header comment + `docs/loop-harness.md` updated (gap closed, not a standing limitation)
- [x] CHANGELOG entry + VERSION → 0.28.1 (PATCH)
- [x] `working/md-has-italic-gap-verify.sh` PASS (own fixtures, independent of the in-lib self-test)
- [x] `verifier-lib --self-test` green; `dev.sh verify` 6/6; honesty-riders prose asserts non-regressive (22/22; only its stale VERSION pin flipped, then pruned per merged-PR convention)

## Guardrails (must not touch)

- The `has()` raw-grep idiom (only md_normalize/md_has change)
- snake_case + dunder preservation (regression guard — these must keep matching)

## Verifier

Independent: `working/md-has-italic-gap-verify.sh` builds its own fixtures and asserts md_has through
the public function, separate from the lib's self-test. Cross-checked by the self-test, `dev.sh verify`,
and the unchanged honesty-riders verifier still passing.

## Execution log

- 2026-06-28 — Contract negotiated (goal, R2, G3). Phase 1.5 skipped (concrete). Design fork resolved:
  direct boundary-aware fix, not an opt-in matcher (opt-in perpetuates the author-must-remember tax).
  Branch `fix/md-has-italic-gap` cut from main (v0.28.0).
- 2026-06-28 — Implemented. `md_normalize` gained a `sed -E` pair-matching rule
  `s/(^|[^[:alnum:]_])_([[:alnum:]]([^_]*[[:alnum:]])?)_([^[:alnum:]_]|$)/\1\2\4/g` — strips a complete
  `_word_` emphasis pair (both delimiters, flanked by non-word chars), leaving snake_case, `_phase`, and
  `__dunder__`/`mcp__` runs intact. Verified on BSD/macOS sed. Self-test flipped + 2 preservation asserts
  added (12→13 asserts). Independent verifier PASS (15/15); dev.sh verify 6/6; residuals R1 clean.
  Refined the rule mid-build from the summary's single-sided strip to a pair-match after noticing the
  single-sided form would corrupt leading-underscore identifiers like `_phase` (used by contract drafts).
  COMPLETE.
