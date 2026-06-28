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

For the gold-standard level, spawn a genuinely independent reviewer on a different in-house model:

```bash
CLAUDEWARP_QA_MODEL=sonnet claude -p '/claude-warp-new-agent "contract-checker (red-team / Skeptic):
review tests/dogfood/trivially-passing-contract.yaml against the Phase 6 failure-pattern checklist.
Which acceptance criteria / stop.check admit a trivially-passing implementation? Reasoning-blind:
judge the artifact alone. Raise blocking findings only; severity-tag them."'
```

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

### 5. Update the backlog

Write the evidence block and the new status into `BEHAVIOURAL-CLAIMS.md`. Future retros append here as
more claims are dogfooded.
