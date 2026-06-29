# Goal: Reproduction-required corroboration on the merge-gating reviewers (Option 2.5)

**Slug:** reproduction-required · **Risk:** R2 · **Source:** MULTI-LENS-REVIEW-analysis.md Option 2.5 (lines 415-418), §6bis line 464, Decision 3 (lines 549-564), recommended-sequence (line 489)

## Objective

Add **reproduction-required corroboration** to ClaudeWarp's two merge-gating reviewers — the cheapest
real-independence proxy (no second vendor, no panel). A reviewer **finding** must be **reproduced by a
second pass** before it blocks; a merge-gating **PASS** must be **corroborated** (not a solo green).
Additive to the v0.28.0 honesty riders + v0.29.0 red-team / Skeptic charter, which stay verbatim. Seams
(analysis §6bis line 464 — "new-harness verifier/QA loop + stop.evidence rule"):

1. **new-harness** — QA evaluator persona gains a "Reproduction-required corroboration" section; runner
   Phase 6 gains a `--corroborate` flag (auto-on at R3+, opt-in at R2) running ONE reproduction pass on a
   DIFFERENT in-house model (`CLAUDEWARP_QA_MODEL`, Opus↔Sonnet).
2. **contract Phase / schema** — `stop.evidence` gains a corroboration clause (R2+ merge-gating PASS
   should be corroborated; a solo pass is labeled `uncorroborated`).

## Done conditions

- [x] new-harness QA evaluator gains a Reproduction-required corroboration section: a blocking critical/major FAIL reverts the task ONLY if a second pass reproduces it; else DOWNGRADE to recorded non-blocking minor with provenance; a merge-gating PASS is CORROBORATED only if the second pass also passes, else UNCORROBORATED
- [x] new-harness runner Phase 6 gains a `--corroborate` flag: parsed, auto-on at R3+ (opt-in at R2/below), runs ONE reproduction pass after a blocking QA FAIL or a merge-gating PASS via a `CLAUDEWARP_QA_MODEL` second-model swap; added to the `To run:` help + the "runner will" list + the DOER/CHECKER note
- [x] Provenance tags: every finding/verdict carries `[pass-N / model]` so agreement is N traceable data points, not headcount (robertoecf)
- [x] Graceful degradation: if the second pass cannot run, mark "single-pass, uncorroborated" LOUD — never silently treat a solo pass as corroborated (P6: NOT corroborated ≠ corroborated) (robertoecf)
- [x] contract `stop.evidence` gains the corroboration clause + one Phase 6 row (R2+ merge-gating PASS should be corroborated; solo = uncorroborated, never silently full evidence)
- [x] v0.28.0 riders + v0.29.0 red-team charter preserved verbatim at both seams (additive, asserted by the verifier)
- [x] Type-B safety preserved: a downgrade / uncorroborated mark Surfaces, never auto-resolves a human-gated decision (a blocking finding that is a deliberate human gate routes to needs_context/blocked, not silently downgraded)
- [x] Three external sources credited where each mechanism lives + docs prior-art rows: /ultrareview (Anthropic)→reproduction-required, alecnielsen/ng→consensus-gating, robertoecf→provenance + graceful-degradation
- [x] docs/loop-harness.md documents Option 2.5; CHANGELOG 0.30.0 + VERSION → 0.30.0 (MINOR)
- [x] `working/reproduction-required-verify.sh` PASS (each mechanism at both seams + riders/charter preserved + credits + docs rows + version); verifier-lib --self-test green; dev.sh verify 6/6; check-ai-residuals --risk R2 clean

## Guardrails (must not touch)

- The v0.28.0 honesty-rider text + v0.29.0 red-team / Skeptic charter at both seams — additive only
- No cross-vendor dependency (Decision 3a, held) — the reproduction pass runs on a different IN-HOUSE model
- No new parallel review runtime (no --review-panel / fork / worktree — Option 3, held); `--corroborate` is ONE sequential second pass
- The `--with-qa` R2+ mandatory threshold (untouched — corroboration rides behind the existing QA gate)

## Verifier

Independent: `working/reproduction-required-verify.sh` sources `scripts/verifier-lib.sh`, uses `md_has`
on prose (and literal grep for the `--corroborate` flag token) to assert every mechanism is present at
both seams, plus the three credits, the docs rows, the riders/charter non-regression, CHANGELOG 0.30.0
and VERSION. Cross-checked by verifier-lib --self-test, dev.sh verify 6/6, and check-ai-residuals --risk
R2 (blocking) clean.

## Execution log

- 2026-06-28 — Contract negotiated (goal, R2, G3). Phase 1.5 worth-it gate SKIPPED (concrete settled
  scope; the user explicitly decided to build Option 2.5). Sources read (Phase 2): new-harness QA
  evaluator persona (lines 303-363), runner Phase 6 (lines 388-548), DOER/CHECKER note (786-792),
  contract stop schema (145-148) + Phase 6 not-run row (302). One open fork (auto-on threshold: R3+ vs
  R2+) RESOLVED autonomously to **R3+ auto-on / R2 opt-in** — prototype-grade discipline must not tax the
  common R2 tier with 2× review; rides behind the existing --with-qa gate; overridable via the flag.
  Branch `feat/reproduction-required` cut from main (v0.29.0).
- 2026-06-28 — Implemented at both seams. new-harness: QA evaluator "Reproduction-required
  corroboration" section (reproduce-before-block, downgrade rule, corroborated/uncorroborated PASS,
  provenance `[pass-N / model]`, graceful-degradation-loud, Type-B never silently downgraded) + runner
  Phase 6 `--corroborate` flag (parse, auto-R3+, `CLAUDEWARP_QA_MODEL` second-model reproduction pass,
  pass-1/pass-2 tags, UNCORROBORATED warning on a failed second pass) + help + step-3b. contract:
  `stop.evidence` corroboration clause + Phase 6 row. docs: Option 2.5 element×seam×source table +
  three prior-art credit rows (/ultrareview, alecnielsen/ng, robertoecf). v0.28.0 riders + v0.29.0
  charter preserved verbatim (asserted). CHANGELOG 0.30.0 + VERSION bump. Independent verifier
  `working/reproduction-required-verify.sh` PASS 46/46 (each mechanism at both seams + non-regression +
  credits + docs + version; dogfoods md_has on soft-wrapped/decorated prose). verifier-lib --self-test
  green; dev.sh verify 6/6; check-ai-residuals --risk R2 exit 0 (HIGH=0, 6 pre-existing MEDIUM none from
  diff). STOP.CHECK chain PASS. COMPLETE.
