# Dogfood runbook — exercising the reviewer charters on a planted-defect fixture

This is the repeatable procedure behind [`BEHAVIOURAL-CLAIMS.md`](../../BEHAVIOURAL-CLAIMS.md). Each
instruction-only reviewer feature makes a **behavioural** claim — that applying the charter to a
contract with a given defect *produces a specific catch*. The static `working/` verifiers only prove
the instruction text is **present**; this runbook is how a claim moves from **present** to **fires**.

The target is [`trivially-passing-contract.yaml`](./trivially-passing-contract.yaml) — a deliberately
broken contract whose every planted defect is tagged `# PLANT[<row>]` with the charter row it should
trip. The fixture is **tracked in git** precisely so the dogfood is reproducible by anyone, not a
one-off.

## The two verification levels (keep them distinct — this is the honesty crux)

A dogfood result is recorded against a **controlled vocabulary** that never conflates two very
different strengths of evidence:

- **`verified-on-fixture <date>`** — an **in-context reviewer pass** (you, or any single agent reading
  this repo) applied the charter to the fixture and the predicted catch fired. This proves **the
  instructions cause the catch**: the charter text is sufficient to make a reviewer flag the planted
  defect. It is the cheap, always-available level.
- **`verified-live <date>`** — a **real spawned independent agent** (`claude -p …`, a *different*
  in-house model, reasoning-blind) produced the catch in a fresh context. This is the strong level: it
  shows the catch survives independence, not just an author re-reading their own setup.

**A fixture pass is strictly weaker than a live pass and must never be relabelled as one.** The whole
point of the backlog is to make that gap *visible*, not to paper over it. (P6: NOT corroborated ≠
corroborated; an in-context pass ≠ an independent one.)

## Procedure

### 1. Pick the claim and its predicted catch

Open `BEHAVIOURAL-CLAIMS.md`, choose a row, and note its **predicted catch** — the exact finding the
charter should produce on the fixture (e.g. *"names the `stop.check: true` trivial pass and blocks"*).

### 2. Run the in-context reviewer pass (→ `verified-on-fixture`)

Apply the relevant charter to the fixture **reasoning-blind** — judge the artifact, not any author's
defence of it:

- **Red-team / Skeptic charter** (`claude-warp-contract` Phase 6): walk the failure-pattern table
  against the fixture. The load-bearing rows are *"AC admits a trivially-passing impl"* and
  *"Load-bearing claim verified, not assumed"*.
- **Honesty riders** (v0.28.0): confirm a clean check reports clean (anti-fabrication), a cosmetic nit
  is tagged `minor` and does **not** block (severity→verdict gating), and the pass lists its
  `Unverified` set.
- **Reproduction-required corroboration** (v0.30.0): see step 4.

Record, in the backlog evidence block: the **planted defect**, the **exact catch text** the pass
produced, **which charter row/rule fired**, and a **pointer to this fixture**. Only then flip the
status to `verified-on-fixture <date>`. **If the catch does NOT fire, leave the status `unverified`
and record the negative result** — never flip a claim to make a bar pass.

### 3. (Optional, strong) Run a live spawned pass (→ `verified-live`)

For the gold-standard level, spawn a genuinely independent reviewer on a **different in-house model**
(cross-model same-vendor independence — e.g. Sonnet when the drafter was Opus).

> **Contamination guard (load-bearing).** Review the **hint-stripped twin**
> [`contract-under-review.yaml`](./contract-under-review.yaml), **never** the
> [`trivially-passing-contract.yaml`](./trivially-passing-contract.yaml) fixture — the latter's
> `# PLANT[<row>]` tags name every defect inline and would leak the answer, turning a `verified-live`
> test into a reading exercise. The reviewer must find the defects by its own judgment. Keep the two
> files in sync (same defects, the twin just has the hints removed).

Two equivalent ways to spawn a real, fresh-context, reasoning-blind reviewer:

```bash
# (a) the claude -p CLI, on a different model
CLAUDEWARP_QA_MODEL=sonnet claude -p --model sonnet 'Red-team / Skeptic review of
tests/dogfood/contract-under-review.yaml against the claude-warp-contract Phase 6 failure-pattern
checklist. Which acceptance criteria / stop.check admit a trivially-passing implementation? Which
load-bearing claim was assumed, not verified? Reasoning-blind: judge the artifact alone, you are not
told the expected findings. Raise blocking findings only; severity-tag them; end with a VERDICT, a
confidence: N/10 line, and an Unverified: set.'
```

…or **(b)** a spawned subagent on `model: sonnet` (what Dogfood D2 used — fresh context, different
model, given only the contract + the checklist). Both satisfy the `verified-live` bar: a real spawned
independent agent, a different in-house model, reasoning-blind, fresh context.

This **costs budget and may be unreliable** in some environments — it is optional, never a hard
requirement of the backlog. Only a real spawned run earns `verified-live <date>`; do not infer it from
the in-context pass.

### 4. Corroboration / reproduction scenario (for the v0.30.0 claim)

The fixture's `PLANT[non-reproducible-finding]` scripts a first pass that raises *"budget.loop_max_usd
is missing"* — which is **false** (`loop_max_usd: 5` is present). A reproduction pass that actually
reads the fixture cannot reproduce it, so under reproduction-required corroboration the finding must be
**downgraded to a non-blocking minor**, never used to block. Meaningfully exercising this needs **two
independent passes** (ideally the live `CLAUDEWARP_QA_MODEL` swap above) — a single in-context agent
playing both passes is theatre, so this claim stays `unverified` until a live run is done. Recording
that limitation honestly *is* the deliverable.

### 5b. Converge reconciliation dogfood (claim #3)

Claim #3 (`/converge`) is **not** a reviewer-verdict mechanism — it reconciles **actual repo state
against contract intent** and classifies gaps. To dogfood it, point a reviewer at the self-contained
fixture tree [`converge-fixture/`](./converge-fixture/) and have them run the `/converge` procedure
(goal mode, read-only) against its `contract.yaml`:

```bash
# (a) the claude -p CLI, on a different model, with the fixture as the repo root
CLAUDEWARP_QA_MODEL=sonnet claude -p --model sonnet '/claude-warp-converge — reconcile the present
state of tests/dogfood/converge-fixture/ against its contract.yaml. Run the stop.check, classify every
gap (missing/partial/contradicts/unrequested) with a source_ref + severity, surface a must_not_touch
contradiction as Type-B, and conclude converged or NOT. Reasoning-blind: you are not told the expected
gaps.'
```

…or **(b)** a spawned subagent on `model: sonnet` (what Dogfood D3 used). The fixture is built so the
`stop.check` **passes** (`src/api/health.js` exists) while a `must_not_touch` path is **violated**
(`src/db/` modified) and a `may_touch` intent item is **missing** (`docs/api.md` absent) — so a correct
reconciliation surfaces `contradicts` + `missing` and reports **NOT converged**, where a naive one
declares done on the green `stop.check`. The fixture is **hint-stripped** (the D2 contamination guard):
nothing in it names the gaps.

### 5. Update the backlog

Write the evidence block and the new status into `BEHAVIOURAL-CLAIMS.md`. Future retros append here as
more claims are dogfooded.
