# Behavioural-claim backlog

ClaudeWarp's reviewer features are **instruction-only** — they live as charter text in skill files,
not as executable code. A static `working/` verifier can prove that text is **present**; it cannot
prove the charter actually *fires* — that applying it to a real defect produces the predicted catch.
This backlog is the standing ledger of that gap. Every instruction-only reviewer feature is registered
here with the **behavioural claim** it makes, the **catch it predicts** on a deliberately-planted
defect, and a **status** that says how far the claim has been validated.

It exists so the gap stays **visible** instead of accumulating silently: four consecutive features
(v0.28.0 → v0.30.0) each asserted behaviour that only live use can confirm. The reproducible procedure
that moves a claim from *present* to *fires* is [`tests/dogfood/RUNBOOK.md`](tests/dogfood/RUNBOOK.md),
run against the tracked fixture [`tests/dogfood/trivially-passing-contract.yaml`](tests/dogfood/trivially-passing-contract.yaml).
Future `/claude-warp-retro` runs append dogfood results here.

This backlog **dogfoods the claim** rather than asserting it — the NOT-RUN-≠-pass / reproduce-before-trust
discipline is adapted from **idea-to-ship-skills** (nelsonwerd) and **/ultrareview** (Anthropic),
applied critically to ClaudeWarp's own reviewers (a fixture pass is treated as strictly weaker evidence
than a live run — see the vocabulary below).

## Controlled vocabulary (status)

The status of each claim is exactly one of these — and `verified-on-fixture` is never silently treated
as `verified-live`:

| Status | Means | Strength |
|---|---|---|
| `unverified` | The charter text is present, but no dogfood has produced the predicted catch yet. The default for every new reviewer claim. | none (present only) |
| `verified-on-fixture <date>` | An **in-context reviewer pass** applied the charter to the tracked fixture and the predicted catch fired. Proves **the instructions cause the catch** — the charter is sufficient to make a reviewer flag the planted defect. | medium |
| `verified-live <date>` | A **real spawned independent agent** (`claude -p`, a different in-house model, reasoning-blind, fresh context) produced the catch. Proves the catch **survives independence**, not just an author re-reading their own setup. | strong |

**Honesty crux (P6 on our own claims):** a `verified-on-fixture` pass shows the **instructions cause
the catch** — it is **NOT** proof that a **live spawned independent agent** catches it in production.
A fixture pass is strictly weaker than a live pass and is never relabelled as one. The point of this
backlog is to make that gap visible, not to paper over it.

## Registry

### 1. Honesty riders on the critical pass — v0.28.0 — STATUS: `verified-on-fixture 2026-06-28`

- **Behavioural claim:** the contract Phase 6 critical pass reports a clean contract as clean **without
  fabricating findings**, gates only on `critical`/`major` (a cosmetic nit is tagged `minor` and does
  not block), caps its confidence by the verified ratio, and lists what it could not check in an
  `Unverified` set.
- **Predicted catch:** on the fixture, the pass raises only findings that map to real planted defects
  (no invented concerns), tags the thin `decision_log` as a non-blocking `minor`/recommendation, and
  closes with a `confidence: N/10` line plus an `Unverified` set.
- **Evidence:** see [Dogfood D1](#dogfood-d1--2026-06-28) — the executed pass reported three findings,
  each quoting a real `PLANT[...]` line (no fabrication); routed the `decision_log` thinness to a
  non-blocking `minor`; and emitted a confidence line + an Unverified set. (Asymmetry noted honestly:
  "did not fabricate" is weaker to demonstrate than "did catch" — this flip rests on the pass's
  observed reporting discipline, not on a forced negative.)

### 2. Red-team / Skeptic reviewer charter — v0.29.0 — STATUS: `verified-on-fixture 2026-06-28`

- **Behavioural claim:** the red-team charter, applied reasoning-blind to a contract, **names the way
  the contract passes without doing the work** — specifically an acceptance criterion / `stop.check`
  that admits a trivially-passing implementation, and a load-bearing claim that was assumed rather than
  verified — and raises them as blocking findings.
- **Predicted catch:** on the fixture, the charter names the `stop.check: "true"` trivial pass and
  blocks; it also flags `validateToken()` as an assumed-not-verified load-bearing claim and the
  `verifier.independent: false` reviewer-bias defect on an R2 merge-gated contract.
- **Evidence:** see [Dogfood D1](#dogfood-d1--2026-06-28). The **"AC admits a trivially-passing impl"**
  row fired (primary catch), alongside the **"Load-bearing claim verified, not assumed"** and
  **"Independent verifier (R2+)"** rows. This is the cleanest flip — a positive catch with quoted
  evidence.

### 3. `/converge` reconcile — v0.19.0 — STATUS: `unverified`

- **Behavioural claim:** given two reviewer passes that **disagree**, `/converge` produces a single
  reconciled verdict that **surfaces the dissent** (re-tickets the conflict) rather than silently
  picking one side.
- **Predicted catch:** feed two conflicting verdicts on the fixture → `/converge` records both, names
  the conflict, and reconciles without dropping the minority finding.
- **Why still `unverified`:** reconciliation needs **two genuinely independent passes** as input. A
  single in-context agent generating both sides is theatre. This flips only with a live run (RUNBOOK
  step 3) producing two real verdicts — held until then, honestly.

### 4. Reproduction-required corroboration — v0.30.0 — STATUS: `unverified`

- **Behavioural claim:** a blocking finding reverts/blocks **only if a second pass reproduces it**; an
  unreproduced finding is **downgraded to a non-blocking minor**; a solo merge-gating PASS is labelled
  `uncorroborated`, never silently counted as full evidence.
- **Predicted catch:** the fixture's `PLANT[non-reproducible-finding]` scripts a first pass raising
  *"budget.loop_max_usd is missing"* (false — `loop_max_usd: 5` is present). A reproduction pass that
  reads the fixture cannot reproduce it, so the finding is **downgraded**, not used to block.
- **Why still `unverified`:** like #3, a meaningful test needs **two independent passes** (ideally the
  `CLAUDEWARP_QA_MODEL` Opus↔Sonnet swap, RUNBOOK step 4). A single agent playing both passes cannot
  honestly demonstrate reproduction. Held for a live run.

## Dogfood log

### Dogfood D1 — 2026-06-28

- **Procedure:** [`tests/dogfood/RUNBOOK.md`](tests/dogfood/RUNBOOK.md) step 2 (in-context reviewer
  pass, `verified-on-fixture` level).
- **Fixture:** [`tests/dogfood/trivially-passing-contract.yaml`](tests/dogfood/trivially-passing-contract.yaml)
  (tracked).
- **Charter applied:** `claude-warp-contract` Phase 6 red-team / Skeptic failure-pattern table + the
  v0.28.0 honesty riders, **reasoning-blind** (judging the fixture on its own merits, no author defence).
- **Findings produced (the catch):**
  1. `major` — **AC admits a trivially-passing impl** [`PLANT[trivially-passing-AC]`]: *"`stop.check:
     "true"` always exits 0 — it passes on an empty stub, a hardcoded value, or no implementation of
     token validation at all. A check that can't fail proves nothing. Make it run the auth test suite
     and fail when expired tokens are accepted."*  ← **predicted catch fired** (claim #2 primary).
  2. `major` — **Load-bearing claim verified, not assumed** [`PLANT[load-bearing-claim]`]: *"the action
     assumes `validateToken()` is already exported in `src/auth/`, drafted from memory not read against
     the repo. Verify it against the source or move it to the Unverified set."*
  3. `critical` — **Independent verifier (R2+)** [`PLANT[independent-verifier-R2]`]: *"R2 is merge-gated
     and requires an independent verifier; `verifier.independent: false` self-grades (the loop re-runs
     its own stop.check). Reviewer bias."*
- **Honesty-rider behaviour observed (claim #1):** every finding quotes a real `PLANT[...]` line — **no
  fabricated findings** (anti-fabrication held); the thin `decision_log` was tagged a non-blocking
  `minor`, not escalated (severity→verdict gating held); the pass closed with **`confidence: 9/10`**
  (3 of 3 load-bearing rows checked against the fixture text; capped because the `true` exit code was
  reasoned definitionally, not executed in a shell) and an **`Unverified` set**: the live spawned pass
  (step 3) was not run, the `stop.check` command was not executed here, and the non-reproducible-finding
  scenario (#4) was not exercised with two independent passes.
- **Verdict:** BLOCK — 1 critical + 2 major. The predicted catches for claims #1 and #2 **fired**;
  both flip to `verified-on-fixture 2026-06-28`. Claims #3 and #4 remain `unverified` (need a live /
  two-pass run; recording that limitation is itself the honest outcome).
