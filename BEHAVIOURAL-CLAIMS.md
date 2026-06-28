# Behavioural-claim backlog

ClaudeWarp's reviewer features are **instruction-only** — they live as charter text in skill files,
not as executable code. A static `working/` verifier can prove that text is **present**; it cannot
prove the charter actually *fires* — that applying it to a real defect produces the predicted catch.
This backlog is the standing ledger of that gap. Every instruction-only reviewer feature is registered
here with the **behavioural claim** it makes, the **catch it predicts** on a deliberately-planted
defect, and a **status** that says how far the claim has been validated.

It exists so the gap stays **visible** instead of accumulating silently: five reviewer features
(v0.28.0 → v0.32.0) each asserted behaviour that only live use can confirm — and all five have now been
flipped by a live spawned independent pass. The backlog stands at **5/5 `verified-live`** (claim #5,
command-verification, flipped by Dogfood D5 on 2026-06-29). The reproducible procedure
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

**Independence has tiers — `verified-live` is *same-family*, not cross-vendor.** Our live pass runs on a
different *in-house* model (Opus↔Sonnet): it neutralises author-bias and filters non-reproducible findings,
but two same-vendor models can share a training-induced blind spot. A `verified-live` claim is therefore
**same-family corroboration (shared blind spots possible)**, never full cross-vendor independence — a
strictly stronger, still-**unproven** level (Decision 3a, held). Two corollaries follow, and both bind the
reproduction pass (claim #4):
- **Static-inference consensus ≠ corroboration.** Agreement two passes reach by reading the **same source
  lines** (or by one citing the other rather than the source) is `[STATIC-INFERENCE-CONSENSUS]` — consensus
  on an *interpretation*, not corroboration of a *fact*. It does **not** compound to `verified-live` and
  cannot gate a merge on its own.
- **A command-confirmed predicate beats a re-read.** When a blocker's predicate is a checkable fact, a
  read-only command that confirms (`[CMD_CONFIRMED]`) or refutes (`[CMD_CONTRADICTED]`) it is harder evidence
  than a second reading; a `[CMD_CONTRADICTED]` blocker is demoted one level. Only an independently re-derived
  catch or a `[CMD_CONFIRMED]` predicate compounds to corroborated.

Credit: **agent-review-panel** (wan-huiyan) — read-only command-verification + the same-lines-consensus
caution; **llm-council** (karpathy) — "unanimous ≠ independent"; the recall-vs-precision (find/verify)
framing of the /ultrareview ecosystem, with research grounding in **NABAOS / tool-receipts** (arXiv 2603.10060).

## Registry

### 1. Honesty riders on the critical pass — v0.28.0 — STATUS: `verified-live 2026-06-28`

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
- **Live evidence:** see [Dogfood D2](#dogfood-d2--2026-06-28-verified-live) — a spawned Sonnet reviewer
  (different model, reasoning-blind) reported budget **CLEAN** rather than inventing a finding
  (anti-fabrication held under independence), severity-tagged every finding, and closed with a
  `confidence: 9/10` line + an `Unverified:` set. **Flipped `verified-on-fixture` → `verified-live`.**

### 2. Red-team / Skeptic reviewer charter — v0.29.0 — STATUS: `verified-live 2026-06-28`

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
- **Live evidence:** see [Dogfood D2](#dogfood-d2--2026-06-28-verified-live) — a spawned Sonnet reviewer
  (different model from the Opus drafter, reasoning-blind, hint-stripped fixture) **independently named
  the `stop.check: "true"` trivial pass** ("an empty `src/auth/` satisfies this check"), the
  assumed-not-verified `validateToken()` claim, and the `independent: false` self-grading tautology —
  BLOCK, `confidence: 9/10`. The catch survived independence, not just self-review. **Flipped
  `verified-on-fixture` → `verified-live`.**

### 3. `/converge` reconcile — v0.19.0 — STATUS: `verified-live 2026-06-28`

- **⚠ Correction (D3 honesty gate, 2026-06-28):** this claim previously described `/converge` as
  reconciling *"two reviewer passes that disagree"* into a verdict that *"surfaces the dissent"*. That
  was a **mischaracterization** — caught by the Phase-2 mandatory read of
  [`skills/claude-warp-converge/SKILL.md`](skills/claude-warp-converge/SKILL.md) while setting up the
  D3 dogfood. `/converge` **never takes reviewer verdicts as input.** Per SKILL.md it reconciles
  **actual repo state against contract intent**. The claim is restated below to match the real
  mechanism; the prior framing is recorded here rather than silently overwritten (the catch is itself
  evidence the gate works).
- **Behavioural claim:** given a contract whose intent the tree only **partially** satisfies,
  `/converge` reconciles the **actual repo state against the contract's intent** and classifies every
  gap (`missing` / `partial` / `contradicts` / `unrequested`) with a nameable `source_ref` — it
  **surfaces a `must_not_touch` contradiction as a Type-B decision** and **refuses to declare
  "converged"** while any gap remains. It does **not** silently drop a gap because other checks pass.
- **Predicted catch:** feed it a partial-satisfaction fixture where the `stop.check` **passes** but a
  `scope.must_not_touch` path is **violated** and a `scope.may_touch` intent item is **missing** →
  `/converge` must report the `contradicts` (under `⚠ SURFACE`) **and** the `missing`/`partial` gap,
  and conclude **NOT converged** — where a naive reconciler would see the green `stop.check` and
  declare done.
- **Live evidence (Dogfood D3, below):** a spawned **Sonnet** agent (different in-house model,
  reasoning-blind) ran `/converge` on the hint-stripped partial-satisfaction fixture and **independently**
  classified the `missing` doc gap and the `contradicts` `must_not_touch` breach, **surfaced** the latter
  as Type-B, and concluded **NOT converged** — *"the stop.check is green, but it covers only one of two
  action clauses and cannot see the guardrail breach."* The catch fired under genuine independence →
  flipped `unverified` → `verified-live 2026-06-28`. (Caveat recorded: it rated the contradicts severity
  lower than the skill's "top severity" guidance, but still surfaced it correctly — the load-bearing
  behaviour held.)

### 4. Reproduction-required corroboration — v0.30.0 — STATUS: `verified-live 2026-06-28`

- **Behavioural claim:** a blocking finding reverts/blocks **only if a second pass reproduces it**; an
  unreproduced finding is **downgraded to a non-blocking minor**; a solo merge-gating PASS is labelled
  `uncorroborated`, never silently counted as full evidence.
- **Predicted catch:** feed a pass-2 reproduction agent a pass-1 findings list carrying two equally-
  confident `critical` blockers against a fixture — one **true-by-fixture** (`stop.check: "true"` admits
  a trivial pass) and one **false-by-fixture** (*"budget.loop_max_usd is missing"* — `loop_max_usd: 5`
  is present) — labelled nowhere. A reproduction pass that actually reads the artifact must **reproduce
  the true blocker (keep it blocking)** and **fail to reproduce the false one (downgrade it to a
  non-blocking minor)**, tagging each `[pass-2 / <model>]`. Downgrading both, or rubber-stamping the
  false one, fails — so a lazy agent cannot pass.
- **Live evidence (Dogfood D4, below):** a spawned **Sonnet** pass-2 agent (different in-house model
  from the Opus drafter, reasoning-blind) independently re-derived both findings from the artifact:
  **reproduced** Finding A (quoting `check: "true"`, kept `critical`) and **did not reproduce** Finding
  B (quoting `loop_max_usd: 5`, *"The field is not missing … Downgraded to non-blocking `minor` per
  reproduction-pass rules"*), with `[pass-2 / sonnet]` provenance and `qa_status: pending` (the real
  blocker stands). The reproduce-or-downgrade behaviour fired under genuine independence → claim **#4
  flips `unverified` → `verified-live 2026-06-28`**. **Scope (P6):** pass-2 — *the mechanism under
  test* — was the live agent; pass-1 was a constructed, realistic findings artifact (the input, the
  reproduction-pass analog of a planted defect). The flip is for the **reproduce/downgrade** behaviour
  with that scope honestly stated, not for a fully-autonomous two-live-agent chain (a panel stays held).

### 5. Command-verification of checkable predicates — v0.32.0 — STATUS: `verified-live 2026-06-29`

- **Behavioural claim:** in the reproduction pass, a blocker whose predicate is a **checkable fact**
  ("field X is missing", "value is Y", "path Z exists") must be reproduced by a **read-only command**
  (`grep`/`cat`/`head`/`tail`/`wc`) and tagged `[CMD_CONFIRMED]` or `[CMD_CONTRADICTED]`; a
  `[CMD_CONTRADICTED]` blocker is **demoted one level**. Agreement reached only by re-reading the same
  lines is `[STATIC-INFERENCE-CONSENSUS]` and does not gate a merge.
- **Predicted catch:** feed a reproduction agent a pass-1 list with a confident `critical` blocker whose
  predicate is **command-falsifiable and false** (e.g. *"`budget.loop_max_usd` is missing"* when
  `grep -n loop_max_usd contract.yaml` returns a hit). An agent following the charter runs the command,
  tags the finding `[CMD_CONTRADICTED]` quoting the matching line, and **demotes it** — rather than
  rubber-stamping or re-asserting it from a second silent reading.
- **Live evidence (Dogfood D5, below):** a spawned **Sonnet** pass-2 agent (different in-house model,
  reasoning-blind, fresh context, given no hint which finding was true) ran read-only `grep` on the artifact
  for **both** findings: it confirmed Finding A (`grep -n 'check'` → `27: check: "true"`, **`[CMD_CONFIRMED]`**,
  kept `critical`) and contradicted Finding B (`grep -n 'loop_max_usd'` → `20: loop_max_usd: 5`,
  **`[CMD_CONTRADICTED]`**, **demoted `critical` → `major`**), with a `[pass-2 / sonnet]` verdict. The
  reproduce-by-executing-and-demote behaviour fired under genuine independence → claim **#5 flips
  `unverified` → `verified-live 2026-06-29`**. The spawn was wrapped by `scripts/reviewer-guard.sh`, which
  confirmed the tree was **unchanged** (the reviewer was provably read-only), so the evidence is
  integrity-clean. Adapted from **agent-review-panel** (wan-huiyan). The deterministic
  `scripts/reviewer-guard.sh` read-only guard (from **dementev-dev/adversarial-review**) is mechanical
  (self-tested), so it carries no behavioural claim of its own — but D5 is the first run to exercise it live.

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

### Dogfood D2 — 2026-06-28 (verified-live)

- **Procedure:** [`tests/dogfood/RUNBOOK.md`](tests/dogfood/RUNBOOK.md) step 3 (live spawned pass,
  `verified-live` level). This is the **strong** level — a real independent agent, not a self-read.
- **Reviewer:** a **spawned Sonnet subagent** — a *different in-house model* from the Opus drafter
  (the cross-model same-vendor independence of Decision-3 b.5), **reasoning-blind** (given only the
  contract + the Phase 6 checklist, never the drafting reasoning or the expected findings).
- **Fixture:** [`tests/dogfood/contract-under-review.yaml`](tests/dogfood/contract-under-review.yaml) —
  the **hint-stripped twin** of the tracked fixture. The `# PLANT[<row>]` tags were removed so the
  reviewer had to find the defects by judgment; handing it the tagged fixture would leak the answer and
  contaminate the test. (This contamination guard is the methodology fix D2 surfaced.)
- **Findings the live reviewer produced (independently, no hints):**
  1. `critical` — *"`stop.check: "true"` is the POSIX shell built-in `true`. It exits 0 unconditionally
     … A completely empty `src/auth/` directory satisfies this check."* ← **the trivially-passing-AC
     catch fired under independence** (claim #2 primary prediction).
  2. `major` — *"The action states 'Extend the existing `validateToken()` export' … The decision_log
     admits 'Drafted quickly from memory.' The author explicitly did not verify the repo."* ←
     load-bearing-claim catch.
  3. `critical` — *"`verifier.independent: false` is explicit … the agent writes whatever it likes, runs
     `true`, and self-declares PASS … Self-grading a tautology is the worst possible configuration."* ←
     independent-verifier catch.
- **Honesty-rider behaviour under independence (claim #1):** the live reviewer marked **budget CLEAN**
  rather than inventing a finding (anti-fabrication held when it had every incentive to look thorough);
  severity-tagged every finding; and closed with **`confidence: 9/10`** + an explicit `Unverified:` set
  (whether `src/auth/`/`validateToken()` exist, the token format, the referenceable test suite).
- **Verdict:** BLOCK, `confidence: 9/10`. The single-reviewer charters **fired under genuine
  independence** → claims **#1 and #2 flip `verified-on-fixture` → `verified-live 2026-06-28`**. Claims
  #3 (`/converge`) and #4 (reproduction-required) stay `unverified`: they are **two-pass** mechanisms,
  and one live pass — which raised no non-reproducible finding to downgrade and produced only one
  verdict to reconcile — cannot test them. Honest outcome recorded, not stretched.

### Dogfood D3 — 2026-06-28 (verified-live, `/converge`)

- **Why this run exists:** setting it up surfaced a **correction** — the Phase-2 mandatory read of
  [`skills/claude-warp-converge/SKILL.md`](skills/claude-warp-converge/SKILL.md) revealed claim #3's
  prior "two reviewer verdicts" framing was wrong (`/converge` reconciles **repo state vs contract
  intent**, never reviewer verdicts). The claim was corrected (see §3) and the dogfood re-aimed at the
  *real* mechanism. The honesty gate doing its job is itself part of the evidence.
- **Procedure:** [`tests/dogfood/RUNBOOK.md`](tests/dogfood/RUNBOOK.md) step 5b (live spawned pass,
  `verified-live` level), goal mode (read-only — `/converge` reports, never writes, for a goal).
- **Reviewer:** a **spawned Sonnet subagent** — a *different in-house model* from the Opus drafter,
  **reasoning-blind** (given the `/converge` procedure + the fixture tree, never the expected gaps).
- **Fixture:** [`tests/dogfood/converge-fixture/`](tests/dogfood/converge-fixture/) — a self-contained
  mini-repo, **hint-stripped** (nothing names the gaps). By construction the `stop.check`
  (`test -f src/api/health.js`) **passes**, while a `must_not_touch` path is **violated** (`src/db/`
  modified) and a `may_touch` intent item is **missing** (`docs/api.md` absent).
- **Classification the live agent produced (independently, no hints):**
  - `missing` · `source_ref: action` (documentation clause): *"the `action` reads 'document it in
    docs/api.md.' The file does not exist anywhere in the tree … the `stop.check` passes but it only
    gates the endpoint file — the documentation obligation is wholly unmet."*
  - `contradicts` · `source_ref: scope.must_not_touch:src/db/`: *"`src/db/schema.sql` … 'Added a sessions
    table while wiring the endpoint' … direct admission that `src/db/` was modified … a guardrail
    violation,"* **raised under `⚠ SURFACE — human decision required`** (Type-B, not auto-resolved).
  - **Report header:** `Intent items : 4   satisfied: 2 … Gaps: missing 1 · contradicts 1 … ⚠ Surfaced: 1`.
- **Honesty behaviour:** **no fabricated gaps** — it classified exactly the two real gaps, no invented
  `unrequested` padding (anti-fabrication held). It ran the `stop.check` mechanically (exit 0) rather
  than assuming, and explicitly noted the green check covers "only one of two action clauses."
- **Verdict:** **NOT converged** — *"Two gaps block convergence … The stop.check is green, but it
  covers only one of two action clauses and cannot see the guardrail breach."* The predicted catch
  **fired under genuine independence** → claim **#3 flips `unverified` → `verified-live 2026-06-28`**.
- **Caveat (recorded, not glossed):** the agent rated the `contradicts` severity `R0` where the skill
  calls a `must_not_touch` breach top-severity. It still **surfaced** it as Type-B — the load-bearing
  behaviour (surface, don't swallow) held; only the numeric severity was under-rated. A minor honest
  blemish, not a failure of the catch.
- **Remaining:** claim #4 (reproduction-required) stays `unverified` — a genuinely two-pass mechanism
  (a finding raised in pass 1, reproduced-or-downgraded in pass 2) that needs an honestly non-reproducible
  finding, which D2 showed is hard to engineer to order. Deferred, recorded honestly.

### Dogfood D4 — 2026-06-28 (verified-live, reproduction-required corroboration)

- **Procedure:** [`tests/dogfood/RUNBOOK.md`](tests/dogfood/RUNBOOK.md) step 5c (the two-pass live run).
  The mechanism under test (v0.30.0) is the **pass-2 reproduction agent** — where the reproduce-or-
  downgrade logic lives ([`skills/claude-warp-new-harness/SKILL.md`](skills/claude-warp-new-harness/SKILL.md)).
- **Reviewer:** a **spawned Sonnet pass-2 agent** — a *different in-house model* from the Opus drafter,
  **reasoning-blind** (given the reproduction-pass charter + the artifact + pass-1's findings; **not** told
  which finding was sound).
- **Fixture:** [`tests/dogfood/repro-fixture/`](tests/dogfood/repro-fixture/) — the hint-stripped
  `contract-under-review.yaml` twin + a constructed-but-realistic [`pass1-findings.md`](tests/dogfood/repro-fixture/pass1-findings.md)
  carrying **two** equally-confident `critical` blockers: **A** `stop.check: "true"` admits a trivial
  pass (**true-by-fixture**), **B** `budget.loop_max_usd` missing (**false-by-fixture** — `loop_max_usd: 5`
  is present). Neither is labelled true/false in the fixture.
- **Contamination caught + re-run (the guard working on our own slip).** The first `pass1-findings.md`
  carried a setup note saying *"one is true-by-fixture, one is false-by-fixture"* — a hint that primed
  pass-2 that exactly one finding was wrong. The D4 verifier's `not_has` check **caught it** (the leak
  words were in the fixture), so the note was stripped to a pure first-pass review and **pass-2 was
  re-spawned on the clean fixture**. The result below is the **uncontaminated** run (same outcome, no
  hint). This is the D2 contamination guard catching the author a second time — recorded, not hidden.
- **What the live pass-2 produced (independently, re-deriving each from the artifact, clean run):**
  - **Finding A → REPRODUCED, stays `critical`:** *"The literal string `"true"` evaluates to exit-0
    unconditionally … An empty `src/auth/` and a completely untouched `validateToken()` both satisfy
    this condition … the loop can declare PASS with zero implementation."* `[pass-2 / sonnet]`
  - **Finding B → NOT REPRODUCED, downgraded to minor:** *"`loop_max_usd: 5` is present. The field is
    not missing. Pass-1's factual predicate is wrong."* → *"downgraded to non-blocking `minor`"* (the
    work is not stalled by an unconfirmed solo finding). `[pass-2 / sonnet]`
  - **Overall:** `qa_status: pending` — *"One reproduced `critical` blocker (Finding A) remains
    standing … Work does **not** proceed."* — `confidence: 9/10`, with an honest `Unverified:` set.
- **Why this is the load-bearing catch:** it is **two-directional**. The pass **kept** the reproducible
  blocker blocking **and** **downgraded** the non-reproducible one — exactly the v0.30.0 guarantee
  (a finding counts only if it reproduces; an unreproduced blocker does not stall). Rubber-stamping B,
  or downgrading both, would have failed; the agent did neither, citing the artifact line-by-line.
- **Honesty caveat (recorded, not glossed):** pass-2's `Unverified` set flagged that it *"did not verify
  the shell interpreter that evaluates `stop.check` (assumed POSIX shell; if the runner uses a custom
  evaluator, the 'true' behavior might differ — but this is unlikely to change the conclusion)"* — an
  honest epistemic hedge that does not weaken the catch (it reproduced A on the plain reading). And
  per P6: **pass-1 was a constructed input artifact, not a live agent** — only pass-2 (the mechanism) was
  live; the flip is scoped to the reproduce/downgrade behaviour, which is what claim #4 asserts.
- **Verdict:** the predicted catch **fired under genuine independence** → claim **#4 flips `unverified` →
  `verified-live 2026-06-28`**. **With this flip the backlog reaches 4/4 `verified-live`** — every
  instruction-only reviewer feature (v0.28.0 → v0.30.0) has now produced its predicted catch under a real
  spawned independent agent. The backlog stays a live ledger: a future same-model blind spot, or a
  cross-vendor independence test, would still be a new, weaker-until-proven claim (P6 holds).

### Dogfood D5 — 2026-06-29 (verified-live, command-verification)

- **Procedure:** [`tests/dogfood/RUNBOOK.md`](tests/dogfood/RUNBOOK.md) step 3 (live spawned pass), applied
  to claim #5 (command-verification). The spawn was wrapped by `scripts/reviewer-guard.sh` (v0.32.0 #3):
  `snapshot` before, `verify` after — the integrity guard's first **live** exercise.
- **Fixture:** the existing [`tests/dogfood/repro-fixture/`](tests/dogfood/repro-fixture/) pair — its
  Finding B (*"`budget.loop_max_usd` is missing"*) is **command-falsifiable and false**
  (`loop_max_usd: 5` is present at line 20), and Finding A (`stop.check: "true"`) is true-by-fixture. No
  reuse change needed; the agent was given the two findings + the artifact path + the command-verification
  rule, **reasoning-blind** (told nothing about which finding was correct).
- **Live agent:** a spawned **Sonnet** subagent (different in-house model, fresh context, reasoning-blind),
  instructed to reproduce each checkable predicate by a **read-only** command only and to write nothing.
- **Catch produced (verbatim):**
  - **Finding A** — ran `grep -n 'check' …/contract-under-review.yaml` → `27:  check: "true"`; tagged
    **`[CMD_CONFIRMED]`**; severity unchanged **critical — BLOCK**.
  - **Finding B** — ran `grep -n 'loop_max_usd' …/contract-under-review.yaml` → `20:  loop_max_usd: 5`;
    tagged **`[CMD_CONTRADICTED]`** (*"The field is not missing; a ceiling of $5 is explicitly set"*);
    applied the one-level demotion **critical → major**. Final verdict tagged `[pass-2 / sonnet]`.
- **Integrity:** `reviewer-guard.sh verify` after the pass returned **`PASS — tree unchanged (reviewer was
  read-only)`** (exit 0) — the spawned reviewer mutated nothing, so the evidence is integrity-clean and the
  v0.32.0 read-only guard (#3) is shown working in a real spawn, not just its `--self-test`.
- **Verdict:** the command-verification behaviour — *reproduce a checkable predicate by executing a read-only
  command, tag `[CMD_CONFIRMED]`/`[CMD_CONTRADICTED]`, and demote a contradicted blocker one level* — **fired
  under genuine independence** → claim **#5 flips `unverified` → `verified-live 2026-06-29`**. **With this
  flip the backlog reaches 5/5 `verified-live`.** P6 holds: pass-1 was a constructed input artifact, only
  pass-2 (the mechanism) was the live agent; a future cross-vendor or same-model-blind-spot test would still
  be a new, weaker-until-proven claim.
