# Goal: Honesty riders for ClaudeWarp review/verdict outputs

**Slug:** honesty-riders · **Risk:** R2 · **Source:** `working/MULTI-LENS-REVIEW-analysis.md` Option 1 (§6, §6bis, §8)

## Objective

Add five honesty riders to ClaudeWarp's existing verdict-emitting surfaces — extending the contract
Phase 6 critical pass, the new-harness QA evaluator, and the Phase 1.5 worth-it verdict. No panel, no
parallel review subsystem, no new runtime (those are Options 3/4, held).

The five riders:
1. **Severity→verdict gating** — findings carry `critical | major | minor | recommendation`; only
   critical/major block, minor/recommendation are recorded and never stall the loop. *(R2+)*
2. **Confidence-capped-by-verified-ratio** — verdicts end with a 1–10 confidence line + a
   "N of M load-bearing claims externally verified; confidence capped by that ratio" tally. *(R2+)*
3. **Anonymized-author rider** — wherever a checker ranks/critiques another agent's output, blind the
   author identity first. *(all tiers)*
4. **Anti-fabrication rule** — "'no blockers' is a valid result; do not manufacture findings to appear
   thorough." *(all tiers)*
5. **"Unverified" set** — every verdict lists what it did NOT check (P6 made visible). *(R2+)*

Tier scoping resolved (user, 2026-06-28): gating/cap/unverified apply at R2+ (advisory below);
anti-fabrication + anonymized-author apply at all tiers.

## Done conditions

- [ ] Rider 1 (severity→verdict gating) present in contract Phase 6 table + new-harness QA evaluator
- [ ] Rider 2 (confidence-cap + verified-ratio) present in Phase 6, QA evaluator, and Phase 1.5 worth-it
- [ ] Rider 3 (anonymized-author) present in Phase 6 critical pass + QA evaluator (all-tiers wording)
- [ ] Rider 4 (anti-fabrication) present in Phase 6 + QA evaluator (all-tiers wording)
- [ ] Rider 5 ("Unverified" set) present in Phase 6, QA evaluator, and Phase 1.5 worth-it
- [ ] `docs/loop-harness.md` documents the riders + credits all four external sources (name + author + link)
- [ ] CHANGELOG entry + VERSION bumped to 0.28.0 (MINOR)
- [ ] `working/honesty-riders-verify.sh` PASS (asserts every rider at its seam, tracked paths only)
- [ ] `scripts/verifier-lib.sh --self-test` green; `check-ai-residuals.sh --risk R2` clean

## Guardrails (must not touch)

- new-harness Phase 6 runner script (no parallel/panel plumbing)
- any new skill / `--review-panel` / fork / worktree runtime
- `scripts/verifier-lib.sh` (reuse via `source`, do not modify the matcher)
- Option 2 (red-team charter) and Option 2.5 (reproduction-required) — separate batches

## Verifier

Independent: `working/honesty-riders-verify.sh` sources `scripts/verifier-lib.sh` and asserts each
rider's instruction is present at its named seam (tracked paths only). Known ceiling: instruction-file
change — verifier confirms presence, not end-to-end behaviour.

## Execution log

- 2026-06-28 — Contract negotiated (goal, R2, readiness G3). Phase 1.5 skipped (concrete change). Tier
  decision surfaced and resolved by user (recommended split). Branch `feat/honesty-riders` cut from main
  (v0.27.0). Contract + GOAL materialised.
