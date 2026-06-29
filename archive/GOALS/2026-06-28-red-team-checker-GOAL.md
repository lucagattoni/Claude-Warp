# Goal: Red-team / Skeptic charter + reasoning-blind discipline on the independent reviewers

**Slug:** red-team-checker · **Risk:** R2 · **Source:** MULTI-LENS-REVIEW-analysis.md Option 2 (§6, §6bis, §8)

## Objective

Give ClaudeWarp's two independent reviewers a **Skeptic / red-team charter** ("try to break it") plus
an explicit **reasoning-blind** framing and **control-validation** rule — additive to the v0.28.0
honesty riders, which stay verbatim. Seams (analysis §6bis: Options 1/2/2.5 are disciplines that apply
to **both** seams):

1. **contract Phase 6** — the R3+ independent checker spawn charter + the critical-pass checklist.
2. **new-harness** — the QA evaluator persona + the optional DOER/CHECKER spawn.

## Done conditions

- [x] contract R3+ checker spawn charter upgraded: try-to-break framing + trivially-passing-AC + unverified-load-bearing-claim + reasoning-blind (judges artifact+repo, not the drafting reasoning)
- [x] contract critical-pass checklist gains 2 red-team rows (trivially-passing AC; unverified load-bearing claim) in the existing Check|Detects|Fix-prompt format
- [x] new-harness QA evaluator persona gains the Skeptic charter incl. control-validation ("a check that cannot fail proves nothing — confirm each passing cmd: would FAIL on a broken impl")
- [x] new-harness optional DOER/CHECKER spawn prompt gains the same red-team charter
- [x] v0.28.0 honesty riders preserved verbatim at both seams (additive, not a rewrite)
- [x] Type-B safety preserved: a "trivially-passing AC" that is actually a human-gated decision Surfaces, never auto-fails
- [x] Four external sources credited where each mechanism lives + docs prior-art table extended (agent-review-panel / wan-huiyan row): CCH→Skeptic charter, devils-advocate→reasoning-blind, /council→fresh-context single-round, agent-review-panel→control-validation
- [x] docs/loop-harness.md documents the red-team discipline; CHANGELOG 0.29.0 + VERSION → 0.29.0 (MINOR)
- [x] `working/red-team-checker-verify.sh` PASS (asserts each element at BOTH seams); verifier-lib --self-test green; dev.sh verify 6/6; check-ai-residuals --risk R2 clean

## Guardrails (must not touch)

- The v0.28.0 honesty-rider text at both seams (anti-fabrication, anonymized-author, severity gating, confidence cap, Unverified set) — additive only
- No new parallel review runtime (no --review-panel / fork / worktree — Option 3, held)
- Phase 1.5 worth-it gate (untouched — this is a reviewer discipline, not planning-side)

## Verifier

Independent: `working/red-team-checker-verify.sh` sources `scripts/verifier-lib.sh`, uses `md_has` on
prose to assert every charter element is present at BOTH reviewer seams, plus the four credits, the
docs row, CHANGELOG 0.29.0 and VERSION. Cross-checked by verifier-lib --self-test, dev.sh verify 6/6,
and check-ai-residuals --risk R2 (blocking) clean.

## Execution log

- 2026-06-28 — Contract negotiated (goal, R2, G3). Phase 1.5 skipped (concrete). Sources read (Phase 2):
  contract Phase 6 checker + checklist, new-harness QA evaluator + DOER/CHECKER spawn. One scoping fork
  (one checker vs both reviewers) surfaced; user delegated ("help me decide"); resolved to BOTH on the
  analysis §6bis disciplines-apply-to-both-seams basis + the Option 1 precedent. Branch
  `feat/red-team-checker` cut from main (v0.28.1).
- 2026-06-28 — Implemented at both seams. Contract Phase 6: red-team spawn charter + 2 checklist rows +
  reasoning-blind/fresh-context framing + 4 credits. New-harness: QA evaluator Skeptic charter w/
  control-validation + DOER/CHECKER red-team brief + extended credit line. docs red-team table +
  agent-review-panel (wan-huiyan) prior-art row. v0.28.0 riders preserved verbatim. Independent verifier
  PASS 31/31 (dogfooded the v0.28.1 md_has fix — asserted soft-wrapped/asterisk-italic prose directly).
  verifier-lib --self-test green; dev.sh verify 6/6; check-ai-residuals --risk R2 exit 0 (HIGH=0, 6
  pre-existing MEDIUM, none from this diff). COMPLETE.
