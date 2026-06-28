# Goal: Behavioural-claim backlog + repeatable fixture-dogfood validation (Option A)

**Slug:** behavioural-claim-backlog · **Risk:** R1 · **Source:** RETRO.md improvement #1 (twice-recommended) — the live-dogfood / behavioural-claim backlog that discharges the four-feature static-verifier ceiling.

## Objective

Stop the unmeasured-claim debt from silently accumulating, and convert at least one reviewer claim
from **present** to **fires**. Four shipped features — v0.28.0 honesty riders, v0.29.0 red-team /
Skeptic charter, `/converge` reconcile, v0.30.0 reproduction-required corroboration — each carry a
**behavioural** claim that the static `md_has` verifiers prove PRESENT-in-instructions but not
EXECUTING. This goal builds a tracked registry of those claims + a reproducible dogfood procedure,
and runs ONE in-context fixture-dogfood to flip a claim, **honestly labelled** weaker than a live run.

Three deliverables:

1. **`BEHAVIOURAL-CLAIMS.md`** (tracked, root, created by this goal, updated by future retros/dogfoods)
   — one row per instruction-only reviewer feature: feature + version + behavioural claim + predicted
   catch on a planted defect + a STATUS from a controlled vocabulary (`unverified` /
   `verified-on-fixture <date>` / `verified-live <date>`).
2. **`tests/dogfood/`** (tracked) — a deliberately-broken contract fixture (a trivially-passing AC +
   a planted non-reproducible-finding scenario) + a runbook for running the reviewer charter against
   it and recording the result. The live `claude -p` spawned-agent run is an OPTIONAL runbook step.
3. **One executed fixture-dogfood**, recorded in the backlog with an auditable evidence block, flipping
   ≥ 1 claim to `verified-on-fixture <date>`.

## Done conditions

- [x] `BEHAVIOURAL-CLAIMS.md` exists (tracked, root) with a controlled-vocabulary legend distinguishing `unverified` / `verified-on-fixture` / `verified-live`, and the honesty note that a fixture pass shows the instructions cause the catch — NOT that a live spawned agent catches it in prod
- [x] The four instruction-only features each seeded with: feature + version + behavioural claim + predicted catch on a planted defect + a status from the controlled vocabulary
- [x] `tests/dogfood/` holds a tracked, deliberately-broken contract fixture: a trivially-passing acceptance criterion AND a planted non-reproducible-finding scenario for corroboration
- [x] `tests/dogfood/` holds a runbook documenting how to run the reviewer charter against the fixture, record the result, and (optional) escalate to a live `claude -p` spawned-agent run — with the verified-on-fixture vs verified-live distinction stated
- [x] ONE in-context fixture-dogfood executed and recorded with an auditable evidence block: the planted defect, the specific catch the reviewer produced, which charter row / rule fired, and a pointer to the tracked fixture
- [x] ≥ 1 claim flipped to `verified-on-fixture <date>` on the strength of that evidence (and ONLY if the catch actually fired — a dogfood that didn't fire stays `unverified` with the negative result; surface, never paper over)
- [x] `docs/loop-harness.md` documents the backlog + dogfood procedure; credits idea-to-ship-skills (nelsonwerd) + /ultrareview (Anthropic) for the dogfood-the-claim / NOT-RUN-≠-pass framing, adapted critically
- [x] CHANGELOG `[0.31.0]` + VERSION → 0.31.0 (MINOR — new standing capability/registry)
- [x] `working/behavioural-claim-backlog-verify.sh` PASS (registry well-formed, vocabulary, fixture + runbook tracked, dogfood evidence block present + references the fixture, docs row, CHANGELOG, VERSION); verifier-lib --self-test green; dev.sh verify 6/6; check-ai-residuals --risk R1 advisory clean

## Guardrails (must not touch)

- No merge-gating reviewer skill logic (`claude-warp-contract`, `claude-warp-new-harness`) — those disciplines are DONE; this is validation/evidence work, additive only
- No live spawned agent as a HARD requirement — `claude -p` is an OPTIONAL runbook step (budget + reliability); never silently conflate a live run with the fixture pass
- `scripts/verifier-lib.sh` / `scripts/dev.sh` unchanged (only sourced/invoked)
- Options 3/4 held

## Verifier

Independent: `working/behavioural-claim-backlog-verify.sh` sources `scripts/verifier-lib.sh`, uses
`md_has` on prose + raw `has` on literal tokens to assert the registry is well-formed (four features
× claim + predicted-catch + status), the controlled vocabulary is documented, `tests/dogfood/` fixture
+ runbook exist (and `git ls-files` confirms they are TRACKED — not a vacuous check against an
untracked path), the dogfood evidence block is present and references the fixture, the docs row, and
CHANGELOG 0.31.0 + VERSION. Cross-checked by verifier-lib --self-test, dev.sh verify 6/6, and
check-ai-residuals --risk R1 (advisory).

## Execution log

- 2026-06-28 — Contract negotiated (goal, R1, G3). Phase 1.5 worth-it gate SKIPPED (concrete settled
  scope; the user explicitly chose Option A). Two open questions resolved autonomously: backlog at root
  `BEHAVIOURAL-CLAIMS.md` (operational registry, RETRO.md convention); fixtures TRACKED under
  `tests/dogfood/` (reproducibility is the point). Phase 6 red-team hardened the done-bar: the
  verified-on-fixture flip must carry an auditable evidence block (planted defect + catch + firing rule
  + tracked-fixture pointer), not the bare status string — a check that can't fail proves nothing.
  Branch `feat/behavioural-claim-backlog` cut from main (v0.30.0).
- 2026-06-28 — Implemented. `BEHAVIOURAL-CLAIMS.md` (root, tracked): controlled-vocabulary legend
  (`unverified` / `verified-on-fixture` / `verified-live`) + honesty crux + four features seeded
  (claim + predicted-catch + status). `tests/dogfood/` (tracked): `trivially-passing-contract.yaml`
  (every defect tagged `# PLANT[<row>]` — trivially-passing `stop.check: "true"`, assumed
  `validateToken()`, missing R2 independent verifier, a scripted non-reproducible finding) +
  `RUNBOOK.md` (the two verification levels, live run optional). **Dogfood D1 executed** — an
  in-context red-team / Skeptic pass on the fixture, reasoning-blind: 1 critical + 2 major findings,
  the **trivially-passing-AC catch fired** (predicted catch for the v0.29.0 charter), plus
  load-bearing-claim + independent-verifier rows; honesty riders observed (no fabrication, nit gated
  to minor, `confidence: 9/10`, Unverified set). Flipped **v0.29.0 red-team** + **v0.28.0 honesty
  riders** to `verified-on-fixture 2026-06-28`; **/converge** + **v0.30.0 reproduction-required** kept
  `unverified` (need two independent passes / a live run — recorded honestly, not papered over).
  docs/loop-harness.md backlog subsection + CHANGELOG 0.31.0 + VERSION bump. Verifier
  `working/behavioural-claim-backlog-verify.sh` PASS 47/47; verifier-lib --self-test green; dev.sh
  verify 6/6; check-ai-residuals --risk R1 exit 0 (HIGH=0, 5 pre-existing MEDIUM, none from this diff).
  STOP.CHECK chain PASS. COMPLETE 9/9.
- 2026-06-28 — **Dogfood D2 (verified-live), v0.31.1.** Ran RUNBOOK step 3 with the user's explicit
  budget go-ahead: spawned a real **Sonnet** reviewer (different in-house model from the Opus drafter,
  reasoning-blind, fresh context) against the **hint-stripped twin** `tests/dogfood/contract-under-review.yaml`
  (PLANT tags removed so the catch couldn't be read off — a contamination guard surfaced mid-run and now
  tracked + mandated in RUNBOOK step 3). The live reviewer **independently** named the `stop.check: "true"`
  trivial pass ("an empty src/auth/ satisfies this check"), the assumed `validateToken()` claim, and the
  `independent: false` self-grading tautology — BLOCK, confidence 9/10, budget marked CLEAN (anti-fabrication
  held under independence). Catch survived independence → **claims #1 (honesty riders) + #2 (red-team charter)
  flipped `verified-on-fixture` → `verified-live 2026-06-28`**. #3 /converge + #4 reproduction-required stay
  `unverified` (two-pass mechanisms; one live pass can't test them — recorded honestly). Verifier PASS;
  verifier-lib --self-test green; dev.sh verify 6/6; residuals R1 HIGH=0. Branch `feat/dogfood-live-run`.
