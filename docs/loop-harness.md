# ClaudeWarp — Loop Harness Reference

Architecture, skills in depth, and templates reference.

---

## The core model

A **plan** is the spec (any size); **goal / loop / harness** are the *shapes* a plan can take.
"A goal" is a small single-shot plan — not the opposite of "a plan." `/claude-warp-contract`
classifies the shape for you. The full explanation, with the aim of each shape and of the
contract command, lives in **[Concepts — Plans, Shapes, and the Contract](concepts.md)**.

> **External references.** `doc-NN` throughout this doc points to the
> [Claude-Loops knowledge base](https://github.com/lucagattoni/Claude-Loops) (the external
> companion repo) — e.g. `doc-27` =
> [`docs/27-loop-contract.md`](https://github.com/lucagattoni/Claude-Loops/blob/main/docs/27-loop-contract.md).

---

## Native vs harness

ClaudeWarp installs only what Claude Code does not already provide. This boundary
is tracked in `harness-manifest.json` and kept current by `/claude-warp-sync`.

| Capability | Where it lives | Status |
|---|---|---|
| Skill auto-loading | `.claude/skills/` | **Native** (v2.1.157) |
| Subagent fan-out | `Agent` tool, `TaskCreate` | **Native** |
| Worktree isolation | `EnterWorktree`, `isolation: "worktree"` | **Native** |
| Scheduling runtime | `~/.claude/scheduled-tasks/`, `/loop` | **Native** |
| Memory / context | `CLAUDE.md`, `/memory` | **Native** |
| Code review | `/code-review`, `/simplify` | **Native** |
| **Scheduling guards** | `scripts/guard-<name>.sh` | **Harness** |
| **External trigger** | `scripts/run-<name>.sh` + crontab snippet | **Harness** |
| **Cross-run structured state** | `<NAME>_LOG.md` + dedup logic | **Harness** |
| **Changelog monitor / self-pruner** | `/claude-warp-sync` | **Harness** |
| **Loop scaffolder** | `/claude-warp-new-loop`, `/claude-warp-new-harness` | **Harness** |
| **Agent scaffolder** | `/claude-warp-new-agent` | **Harness** |

When a harness row becomes native, `/claude-warp-sync` marks it `superseded`,
logs a migration note in `HARNESS_SYNC_LOG.md`, and adds a deprecation notice
to the affected skill.

---

## Skills

### `/claude-warp-setup`

Per-project installer. Detects project type (Node / Python / Go / Rust / generic),
fills `CLAUDE.md` with real context, creates directory structure, writes
`harness-manifest.json`, and commits.

Install path: `skills/claude-warp-setup/SKILL.md`

---

### `/claude-warp-contract "goal"` ← start here

**The single entry point.** Describe any plan; it specifies it, **auto-routes to the shape**
(single-shot / loop / harness), and hands off to the scaffolder. It absorbed the former
`/claude-warp-new` router and `spec-refine`. Phase 1–10:

1. **Branch (classify the shape)** — single-shot `goal` / `loop` / `harness` from recurrence +
   stage count + scope size (the router, folded in); resume an existing draft if present
2. **Draft-first** — a complete best-guess contract, persisted to `contract.draft.yaml`
3. **Risk classify** R0–R5 (doc-04) → sets interview rigor
4. **Interview** — dynamic, depth scales with risk *and* shape (a goal in ≤3 Qs, a harness more)
5. **Re-classify** risk against the refined contract (bounded to 2 cycles)
6. **Critical pass** — 10 checks mapped to named failure patterns (doc-17); R3+ uses an
   independent cross-model checker, not self-review
7. **Readiness gate** — LCR ≥ 5/6 (6/6 for R3+) for loops; G2+ (G3 for R3+) for goals
8. **Approve** — explicit user sign-off (doc-27 Gate 2)
9. **Materialise** `contract.yaml` (all kinds) + kind-specific projection — anchor files (loop),
   `GOAL.md` (goal), or the subplan decomposition (harness); `--no-scaffold` stops here
10. **Handoff** via `--contract` → `/claude-warp-new-loop`, `/claude-warp-new-goal`, or
    `/claude-warp-new-harness` (which decomposes a big plan into subplans)

Adaptive rigor: an R0 read-only loop clears in ≤3 questions; an R3 prod-adjacent loop is
challenged on every property and forced to define an escalation gate + independent verifier.
Sources: Claude-Loops doc-04, doc-14, doc-17, doc-24, doc-26, doc-27, doc-30.

Install path: `skills/claude-warp-contract/SKILL.md`

**Honesty riders (verdict outputs, v0.28.0).** ClaudeWarp's verdict-emitting surfaces — the contract
critical pass (Phase 6), the contract worth-it verdict (Phase 1.5), and the harness QA evaluator
(`new-harness` Phase 5b) — carry five riders that keep a review from becoming verifier theater. Two
bind at **every risk tier** (free instruction text, no ceremony); three bind at **R2+** (advisory
below, so small R0/R1 goals are not taxed):

| Rider | Tier | What it forces | Source |
|---|---|---|---|
| **Anti-fabrication** | all | "No blockers" is a valid result — never manufacture findings to look thorough | [devils-advocate](https://github.com/brandonsimpson/devils-advocate) |
| **Anonymized-author** | all | Judge the artifact on its merits, author identity/reasoning set aside first | [Karpathy LLM Council](https://github.com/karpathy/llm-council) → `/council` |
| **Severity→verdict gating** | R2+ | `critical/major` block; `minor/recommendation` are recorded, never stall the loop | [CCH TeamAgent Debate](https://github.com/Chachamaru127/claude-code-harness) |
| **Confidence-capped-by-verified-ratio** | R2+ | `confidence: N/10` + "M of K load-bearing claims verified; capped by that ratio" | [idea-to-ship-skills](https://github.com/nelsonwerd/idea-to-ship-skills) |
| **"Unverified" set** | R2+ | Every verdict lists what it did **not** check — P6 (NOT RUN ≠ pass) made visible | [devils-advocate](https://github.com/brandonsimpson/devils-advocate) |

Adapted **critically**: severity gating still routes a Type-B judgment call to Surface (it never
auto-resolves a `minor` that is actually a hidden decision); anonymized-author is same-model here, so
it neutralizes author-bias, not a shared-model-family blind spot (pair with reproduction-required if
that bites). This is Option 1 of the multi-lens-review design space — disciplines on the seams
ClaudeWarp already owns, **not** a parallel review panel.

**Red-team / Skeptic charter on the reviewers (v0.29.0).** The two places ClaudeWarp spawns an
*independent reviewer* — the contract Phase 6 R3+ checker and the `new-harness` QA evaluator (plus the
optional DOER/CHECKER) — carry a **red-team charter**: try to *break* the work, not confirm it. The
charter is additive to the v0.28.0 honesty riders above.

| Element | Where | What it forces | Source |
|---|---|---|---|
| **Try-to-break (Skeptic) charter** | both reviewers | Assume it's wrong; find the way it passes *without doing the work* | [CCH TeamAgent Debate](https://github.com/Chachamaru127/claude-code-harness) |
| **Trivially-passing-AC check** | both reviewers | Flag any acceptance criterion / `stop.check` an empty stub, hardcoded value, or always-0 check satisfies | [CCH TeamAgent Debate](https://github.com/Chachamaru127/claude-code-harness) |
| **Control-validation** | QA evaluator | A passing `cmd:` must be confirmed to **FAIL** on a broken impl — *a check that can't fail proves nothing* | [agent-review-panel](https://github.com/wan-huiyan/agent-review-panel) |
| **Reasoning-blind grading** | both reviewers | Judge the artifact + repo, not the author's defence of it (the R3+ checker is a fresh subagent by construction) | [devils-advocate](https://github.com/brandonsimpson/devils-advocate) |
| **Single fresh-context pass** | R3+ checker | One pass, no debate loop (conformity drift) | [Karpathy LLM Council](https://github.com/karpathy/llm-council) → `/council` |

Adapted **critically**: a "trivially-passing AC" that is actually a deliberate human-gated decision
**Surfaces** as a Type-B call, never auto-fails; a clean red-team result is valid (anti-fabrication
still binds — no invented breaks); same-model reasoning-blind neutralizes author-bias, not a shared
model-family blind spot (that is Option 2.5, below). This is Option 2 of the multi-lens-review design
space — it **strengthens the reviewers ClaudeWarp already spawns**, it does **not** add a parallel
review panel (that is Option 3, held).

**Reproduction-required corroboration (v0.30.0).** The red-team charter above makes a reviewer *sharper*,
but every reviewer is still **same-model** — they share a family blind spot. Option 2.5 adds the cheapest
*independence* proxy without a second vendor or a panel: a finding only counts if it **reproduces**, and a
merge-gating PASS must be **corroborated**, not solo. It attaches to the `new-harness` QA loop and the
contract `stop.evidence` rule (a "new gate on the existing verify step"):

| Element | Where | What it forces | Source |
|---|---|---|---|
| **Reproduce-before-block** | QA evaluator (`--corroborate`) | A blocking finding reverts the task only if a **second pass reproduces it**; an unreproduced finding is downgraded to a recorded non-blocking minor | [/ultrareview](https://www.shareuhack.com/en/posts/claude-code-pr-review-subagents-guide) (Anthropic — `/code-review ultra`) |
| **Corroborated PASS** | QA evaluator + contract `stop.evidence` | A merge-gating PASS is `corroborated` only if a second pass agrees; a solo green is one data point, not confirmation | [adversarial-review](https://github.com/alecnielsen/adversarial-review) (alecnielsen) · [adversarial-review](https://github.com/ng/adversarial-review) (ng) — consensus-gating |
| **Provenance tags** | both | Every finding/verdict carries `[pass-N / model]` so agreement is **N traceable data points, not headcount** | [adversarial-review](https://github.com/robertoecf/adversarial-review) (robertoecf) |
| **Graceful degradation (loud)** | runner + `stop.evidence` | If the second pass can't run, mark `uncorroborated — single-pass` **loudly**; never silently treat a solo pass as corroborated (P6: NOT corroborated ≠ corroborated) | [adversarial-review](https://github.com/robertoecf/adversarial-review) (robertoecf) |
| **Different in-house model** | runner (`CLAUDEWARP_QA_MODEL`) | The reproduction pass runs on Opus↔Sonnet for near-free diversity; same-model still filters non-reproducible findings | Decision-3 b.5 (cross-model same-vendor) |
| **Command-verification** | QA evaluator (reproduction pass) | A checkable-fact blocker must be reproduced by a **read-only command** (`grep`/`cat`/`head`/`tail`/`wc`) and tagged `[CMD_CONFIRMED]`/`[CMD_CONTRADICTED]`; a contradicted blocker is demoted one level — advisory, never auto-deletes | [agent-review-panel](https://github.com/wan-huiyan/agent-review-panel) (wan-huiyan) — read-only command validation + find/verify split; **NABAOS / tool-receipts** (arXiv 2603.10060) |
| **Static-inference consensus ≠ corroboration** | QA evaluator (reproduction pass) | Agreement reached by reading the **same source lines** (or citing pass-1) is `[STATIC-INFERENCE-CONSENSUS]`, not independent corroboration; only a re-derived catch or a `[CMD_CONFIRMED]` predicate compounds | [agent-review-panel](https://github.com/wan-huiyan/agent-review-panel) (wan-huiyan) · [llm-council](https://github.com/karpathy/llm-council) (karpathy) — "unanimous ≠ independent" |
| **Read-only-reviewer guard** | `scripts/reviewer-guard.sh` (runner) | Snapshots the tree (`git status --porcelain` + a tracked-content digest) before/after a spawned review pass; ANY mutation fails **loud** — proving the reviewer was truly read-only | [adversarial-review](https://github.com/dementev-dev/adversarial-review) (dementev-dev) — porcelain + sha256 integrity snapshot |

`--corroborate` is **auto-on at R3+** (prod-adjacent stakes justify the ~2× review) and **opt-in at R2 and
below**; it rides *behind* the existing `--with-qa` gate (no first pass ⇒ nothing to corroborate ⇒ no-op).
Adapted **critically**: this is **one sequential second pass**, not a panel (Option 3, held), on a
different *in-house* model, not cross-vendor (Decision 3a, held — flip to it only if dogfooding shows a
shared-blind-spot bug class that survives reproduction). A downgrade or `uncorroborated` mark **Surfaces**
a Type-B call; it never silently downgrades a human-gated decision.

**Behavioural-claim backlog (v0.31.0).** The four reviewer features above (honesty riders, red-team
charter, `/converge` reconcile, reproduction-required corroboration) are all **instruction-only** — a
static `working/` verifier proves the charter *text is present*, never that the charter *fires* on a
real defect. [`BEHAVIOURAL-CLAIMS.md`](../BEHAVIOURAL-CLAIMS.md) is the standing registry that keeps
that gap visible: each feature is logged with the **behavioural claim** it makes, the **catch it
predicts** on a planted defect, and a **status** from a controlled vocabulary that never conflates two
strengths of evidence —

| Status | Means | Strength |
|---|---|---|
| `unverified` | charter text present; no dogfood has produced the catch yet (the default) | present only |
| `verified-on-fixture <date>` | an **in-context** reviewer pass applied the charter to the tracked fixture and the catch fired — proves *the instructions cause the catch* | medium |
| `verified-live <date>` | a **real spawned independent agent** (`claude -p`, different in-house model, reasoning-blind) produced the catch — proves it *survives independence* | strong |

The reproducible procedure is [`tests/dogfood/RUNBOOK.md`](../tests/dogfood/RUNBOOK.md) run against the
tracked fixture [`tests/dogfood/trivially-passing-contract.yaml`](../tests/dogfood/trivially-passing-contract.yaml)
— a deliberately broken contract whose every planted defect is tagged `# PLANT[<row>]` with the charter
row it should trip. The honesty crux is the vocabulary itself: **a fixture pass is strictly weaker than
a live pass and is never relabelled as one** (P6 applied to our own claims — NOT corroborated ≠
corroborated). This **dogfoods the claim** rather than asserting it, adapting the NOT-RUN-≠-pass
discipline of **idea-to-ship-skills** (nelsonwerd) and the reproduce-before-trust framing of
**/ultrareview** (Anthropic) **critically** — here the subject under test is ClaudeWarp's *own*
reviewers, and an in-context pass is explicitly logged as weaker evidence than a live run.

The first `verified-live` run (v0.31.1, backlog Dogfood D2) flipped the red-team charter and honesty
riders to the strong status: a spawned **Sonnet** reviewer (different model from the Opus drafter,
reasoning-blind, given the hint-stripped twin `contract-under-review.yaml`) independently named the
`stop.check: "true"` trivial pass and BLOCKed — the catch survived independence, not just self-review.
A later live run (v0.31.3, **Dogfood D3**) flipped `/converge` to `verified-live` — but setting it up
first **corrected** the backlog: the Phase-2 read of `skills/claude-warp-converge/SKILL.md` showed claim
#3 had mischaracterized `/converge` as a *reviewer-verdict* reconciler when it actually reconciles **repo
state vs contract intent**. Re-aimed at the real mechanism, a spawned Sonnet agent ran `/converge` on a
hint-stripped partial-satisfaction fixture and independently caught the `missing` doc gap **and** the
`contradicts` `must_not_touch` breach, surfaced the latter as Type-B, and reported **NOT converged** —
the honesty gate both corrected a latent doc error and produced the live evidence.

The final run (v0.31.4, **Dogfood D4**) flipped reproduction-required (#4) too — **the backlog is now
4/4 `verified-live`**. The mechanism under test is the **pass-2 reproduction agent**, so a live Sonnet
pass-2 (reasoning-blind) was fed a constructed pass-1 findings list carrying two equally-confident
`critical` blockers — one true-by-fixture (`stop.check: "true"`), one false-by-fixture
(`loop_max_usd` "missing" — it is present). Re-deriving each from the artifact, it **reproduced** the
true blocker (kept it blocking) and **failed to reproduce** the false one (downgraded it to a
non-blocking minor), with `[pass-2 / sonnet]` provenance — the exact reproduce-or-downgrade guarantee.
P6 is preserved in the record: pass-1 was a constructed *input* artifact, only pass-2 (the mechanism)
was the live agent, and a future cross-vendor or same-model-blind-spot test would still be a new,
weaker-until-proven claim.

**v0.32.0 — corroboration rigor + honest independence.** Three additions deepen the same axis without
wiring in a second vendor. (1) **Command-verification** (claim #5, registered `unverified`): a reproduction
blocker whose predicate is a checkable fact must be reproduced by a **read-only command** and tagged
`[CMD_CONFIRMED]`/`[CMD_CONTRADICTED]` — reproducing by *executing*, not just re-reading. (2) The
**same-family caveat**: `verified-live` is now explicitly labeled *same-family corroboration (shared blind
spots possible)*, never full cross-vendor independence, and agreement reached by reading the same lines is
`[STATIC-INFERENCE-CONSENSUS]`, which does not compound. (3) A deterministic **read-only-reviewer guard**
(`scripts/reviewer-guard.sh`) snapshots the tree before/after a spawned pass and fails loud on any mutation —
turning "the reviewer is read-only" from an assertion into an enforced, self-tested check. Command-verification
shipped as claim #5 (`unverified`) — the honest default for a fresh instruction-only feature.

**v0.32.2 — Dogfood D5 flips claim #5; the backlog reaches 5/5 `verified-live`.** A spawned **Sonnet** pass-2
agent (different in-house model, reasoning-blind, no hint which finding was true) ran read-only `grep` on the
repro fixture for both findings: it **confirmed** Finding A (`grep -n 'check'` → `check: "true"`,
`[CMD_CONFIRMED]`, kept `critical`) and **contradicted** Finding B (`grep -n 'loop_max_usd'` → `loop_max_usd: 5`,
`[CMD_CONTRADICTED]`, **demoted `critical` → `major`**), verdict `[pass-2 / sonnet]`. The spawn was wrapped by
`scripts/reviewer-guard.sh`, whose post-pass `verify` returned *tree unchanged* — so the v0.32.0 read-only guard
(#3) is itself shown working in a real spawn, and the evidence is integrity-clean. Command-verification therefore
flips `unverified` → `verified-live 2026-06-29`, taking the backlog to **5/5 `verified-live`** — every
instruction-only reviewer feature (v0.28.0 → v0.32.0) has now produced its predicted catch under a real spawned
independent agent. The ledger stays live: a cross-vendor or same-model-blind-spot test would still be a new,
weaker-until-proven claim (P6 holds).

---

### `/claude-warp-new-goal "goal"`

Scaffolds a **one-shot bounded goal** — use when the work is non-recurring and
stops when a verifiable criterion is met. ("Loops discover work. Goals finish it.")

**G0–G3 readiness scoring** — before creating files, the skill scores the goal
across four axes (objective clarity, verifier independence, state file, budget).
G0 stops with an explanation; G1–G2 proceed with warnings in GOAL.md.

**Files created:**

| File | Purpose |
|---|---|
| `<slug>-GOAL.md` | State file: Objective, Done conditions, Guardrails, Execution log |
| `scripts/run-<slug>.sh` | Run-once script — re-invokable; GOAL.md tracks progress across context resets |

Install path: `skills/claude-warp-new-goal/SKILL.md`

---

### `/claude-warp-new-loop "goal"`

Scaffolds a complete **recurring** single-agent loop from a one-line goal description.

**Derives from the goal:**
- `SKILL_SLUG`, `SKILL_NAME`, `SKILL_DESCRIPTION`
- `STATE_FILE` — append-only tracking file
- `DEFAULT_SCHEDULE` — suggested cron expression
- `MAX_TURNS` — hard turn cap
- `MAX_BUDGET_USD` — hard cost cap (default $2.00)
- `STOP_CONDITION` — verifiable signal that the loop succeeded
- `ALLOWED_TOOLS` — minimum tool set

**Files created:**

| File | Purpose |
|---|---|
| `.claude/skills/<slug>/SKILL.md` | Loop procedure with phases: guard → state → work → verify → write → stop |
| `scripts/guard-<slug>.sh` | Prevents double-runs (once per day / weekdays only) |
| `scripts/run-<slug>.sh` | Headless runner (`run-headless.sh.tpl`) or fan-out runner (`run-fanout.sh.tpl`, uses `claude --bg --worktree`) based on goal shape |
| `<SLUG>_LOG.md` | Append-only state with IN_PROGRESS recovery |
| `scripts/trigger-<slug>.crontab` | Reference cron snippet (not installed automatically) |

Install path: `skills/claude-warp-new-loop/SKILL.md`

---

### `/claude-warp-new-harness "goal"`

Scaffolds a two-part harness for goals too large for a single loop. Based on
Anthropic Engineering's ["Effective Harnesses for Long-Running Agents"](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

**Two roles:**
- **Initializer agent** — reads the goal and scope; produces a bounded JSON task list; runs once
- **Coding agent** — executes one task at a time; commits after each; reads session-init at the start of every context window for crash recovery

**Files created:**

| File | Purpose |
|---|---|
| `.claude/agents/<slug>-initializer.md` | Planner agent definition |
| `<slug>-features.json` | Task queue: `pending` → `in_progress` → `done` / `failed` (+ optional honest-uncertainty statuses `done_with_concerns` / `needs_context` / `blocked`) |
| `<slug>-session-init.md` | Read by coding agent at every context window start |
| `VISION.md` | High-level goal and success criteria (anchor file) |
| `AGENTS.md` | Role definitions and handoff protocol (anchor file) |
| `PROMPT.md` | Current work unit — edit to re-task without changing rules (anchor file) |
| `scripts/run-<slug>.sh` | Runner: initializer once, then coding agent loop until all tasks done; `--retry` triggers Inner/Outer Dual Loop on stall |

**Decomposition approval gate.** Between the initializer and the coding loop, the runner can pause for the operator to review the proposed task breakdown before any budget is spent executing it. It is **required at R2+** (the same threshold that makes QA non-overridable) and **opt-in below** via `--approve-plan`. When the gate fires, the runner prints the breakdown (wave / id / title / `depends_on`) and **stops with exit 0** — no coding work runs — until you re-run with `--plan-approved` (or `CLAUDEWARP_PLAN_APPROVED=1`). Because `features.json` persists, the approved re-run skips the initializer and proceeds straight to execution. The gate is non-interactive by design, so a scheduled/unattended harness never executes an unreviewed decomposition. (It fires on the initial decomposition only, not on a `--retry` re-init, which is an explicit autonomous stall-recovery mode you've already opted into.)

**`--retry` flag (Inner/Outer Dual Loop with diagnostic routing):** if the coding loop hits `MAX_ITER` with tasks still pending, `--retry` first **classifies the stall's root cause** into one of three layers and routes accordingly, instead of blindly re-decomposing every stall. The intent/spec/code routing is adapted from the diagnostic-failure-routing design in the [**PAUL** project](https://github.com/ChristopherKahler/paul) (*Plan · Apply · Unify Loop*, by Christopher Kahler) — see [`apply-phase.md`](https://github.com/ChristopherKahler/paul/blob/main/src/workflows/apply-phase.md); we adapt it critically (the classifier is non-load-bearing — see below) rather than copying it:

- **code** — the plan was correct, the implementation just doesn't match yet → re-run the coding loop **in place** (no re-decompose).
- **spec** — the plan was missing something or mis-scoped a task → clear the task list and re-invoke the initializer with failure context, then run a final coding pass with a revised breakdown (the original `--retry` behaviour).
- **intent** — the goal itself wants something *different* than what was planned → **Surface to a human** and stop (exit 3); re-planning the same goal cannot fix a wrong goal, so this is a Type-B judgment call that never auto-resolves (constitution P3).

The classifier is a small read-only agent; an uncertain or unparseable verdict falls back to **spec**, so routing is a strict, non-regressive refinement of the prior behaviour. Routing fires **once** (bounded recovery — a deliberate divergence from the PAUL project's max-3 loop, since the coding loop already iterates internally).

**Per-task acceptance + negative scope (optional).** Beyond the global `verification` command, each
task may carry its own done-bar and guardrails — both optional, so existing feature lists keep working
unchanged:
- `acceptance` — an array of Given/When/Then prose criteria and/or `cmd:`-prefixed shell checks that
  grade **this task** specifically. A task at risk tier **R2+** must include at least one `cmd:` check
  (merge-gated work can't pass on prose alone). QA grades against these, falling back to the global
  criteria when a task has none.
- `must_not_change` — the task's **negative scope**: path/globs enforced mechanically via
  `git diff`, plus behaviours the worker must attest it preserved. Complements the positive
  `files_in_scope` allow-list.

**Honest-uncertainty statuses + mandatory R2+ qualify (optional / risk-scaled).** Beyond `done` /
`failed`, a worker may set three honest statuses instead of faking a `done` or flattening a
recoverable hold to a failure (all optional — a harness that never uses them is unchanged):
- `done_with_concerns` — acceptance met **but** with a recorded `concern`. **Completes** (the wave
  proceeds) and the runner **surfaces** the concern in its report. "Done but unsure about X."
- `needs_context` — cannot finish without missing information; a **holding** status (counts as
  not-complete, surfaced for a human). "I won't guess and mark it done."
- `blocked` — externally blocked; also a holding status, surfaced.

`needs_context` / `blocked` are Type-B holds — the runner never auto-resolves them to `done`.
Separately, the **qualify/QA re-read is mandatory and non-overridable at risk R2+** (it runs by
default, no `--no-qa`) — the structural one-level-down enforcement of constitution P2 (merge-gated
work needs an independent verifier). When a task's output isn't independently gradable, QA re-runs its
`acceptance` `cmd:` checks as the grade (a check it can't run is `not run`, never PASS).

Install path: `skills/claude-warp-new-harness/SKILL.md`

---

### `/claude-warp-converge`

**Reconcile-and-re-ticket closure** (optional `--converge` runner tail).
After a harness runs, converge answers one question honestly: *does the actual tree satisfy the
intent, and if not, what is left?* It is **read-only of source** and judges the **present state of
the tree** against the contract + task intent (it is a reconciler, **not a diff tool**). It
classifies every gap — `missing | partial | contradicts | unrequested` — using a **hybrid**
assessment (run task `acceptance`/`stop.check` for `missing`/`partial`; LLM judgment for
`unrequested`/`contradicts`), then **append-only** re-tickets each gap as a `convergence` wave
(tasks tagged `origin: convergence` + `gap_type` + `source_ref`, so a re-run is idempotent). If
nothing is unmet it leaves `features.json` byte-for-byte unchanged and reports `converged`. A
`contradicts` on a `must_not_touch` path or an R4/R5 guardrail **Surfaces** for a human instead of
auto-running. The runner's `--converge` tail (default off) runs it once after all waves and, if it
appended tasks, runs **one** closing coding loop — no re-converge (guards the infinite-fix loop).
For a `kind: goal`, converge reports + prints a ready-to-run `/claude-warp-new-goal` follow-up
rather than mutating `GOAL.md`.

Install path: `skills/claude-warp-converge/SKILL.md`

---

### `/claude-warp-release`

**"PR merged" is not "release ready."** Run before cutting a
release to answer one question honestly: *is this ready to ship, or just merged?* It is **read-only**
— it never tags, commits, or pushes; it **assesses**, packages the evidence (verifier output +
diffstat since the last tag), prints the exact tag/release commands, and emits a **two-tier verdict**:

- **BLOCK** (hard, fail-closed) on the **mechanical** boundaries — VERSION not bumped vs the last tag,
  no matching dated CHANGELOG entry, the target tag already exists, a still-populated `[Unreleased]`,
  or a dirty tree. These are objective; each has one right answer, so each fails closed.
- **WARN + Surface** on the **one judgment** call — whether the bump *severity* matches the inferred
  change type (breaking→MAJOR, new capability→MINOR, fix/doc→PATCH; highest type wins). Because that
  classification is an inference, a suspected mismatch Surfaces for a human and is **never**
  auto-escalated to a BLOCK (constitution P3/P6 — a Type-B judgment is not auto-resolved).

Overall verdict is **PASS** only with zero BLOCKs and every evidence check actually run (NOT RUN ≠
pass). Keeping the gate read-only is deliberate: the readiness-checker stays independent of the
shipper (P2), and the act of releasing remains a Surface. Self-host safe — with no `CHANGELOG.md` /
`VERSION` it reports not-applicable and exits 0. It operationalizes the project's SemVer convention
(release per complete batch, highest-severity bump wins, never leave `[Unreleased]` populated) as a
checkable gate.

Install path: `skills/claude-warp-release/SKILL.md`

---

### `/claude-warp-new-agent "role"`

Scaffolds a specialized subagent definition for use inside loops and harnesses.

**Derives from the role:**
- `AGENT_NAME` — kebab-case identifier
- `AGENT_MODEL` — Opus 4.8 for deep analysis; Sonnet 4.6 for routine work; Haiku 4.5 for fast lookups
- `AGENT_TOOLS` — minimum tool set for the role
- `AGENT_PERSONA` — expertise, focus, output format, and constraints

**Files created:**

| File | Purpose |
|---|---|
| `.claude/agents/<name>.md` | Subagent definition with frontmatter and persona |

Install path: `skills/claude-warp-new-agent/SKILL.md`

---

### `/claude-warp-new-hook "description"`

Scaffolds a deterministic hook script and wires it into `.claude/settings.json`.
Hooks run shell scripts at defined lifecycle points — they are hard gates, not
LLM judgments. Use when a loop needs a guarantee (not best-effort behaviour).

**Four named patterns:**

| Pattern | Event | Behaviour |
|---|---|---|
| `verify-before-stop` | `Stop` | Blocks turn end (exit 2) until `CHECK_CMD` passes; `asyncRewake` re-enters Claude with failure output |
| `destructive-block` | `PreToolUse` | Denies Bash commands matching a regex pattern |
| `audit-log` | `PostToolUse` | Appends all tool calls to `logs/audit.log` asynchronously |
| `subagent-chain` | `SubagentStop` | Triggers follow-on work when a background agent finishes |

**Files created:**

| File | Purpose |
|---|---|
| `hooks/<slug>.sh` | Hook script; exit 2 = blocking deny, exit 0 = allow |
| `.claude/settings.json` | Updated with the new hook entry (appended, not replaced) |

**Safety:** exit code 2 blocks; exit 1 is a non-blocking warning that accidentally permits the denied action. All deny logic must be wrapped so unhandled errors exit 2.

Install path: `skills/claude-warp-new-hook/SKILL.md`

---

### `/claude-warp-inventory`

Zero-LLM self-inspection of the installed ClaudeWarp setup. All phases use Bash
and Read only — no LLM inference.

1. Reads `harness-manifest.json` for installed version
2. Scans `.claude/skills/` for missing SKILL.md files or unknown skills
3. Scans `.claude/agents/` for stale model IDs (post-deprecation)
4. Scans `.claude/settings.json` hooks for missing scripts
5. Detects state-file schema and reads accordingly: loop headers (flags `consecutive_fails >= 3`, `IN_PROGRESS`), goal `GOAL.md` (done-conditions progress; flags stalled), harness `features.json` (flags failed tasks)
6. Checks `scripts/` for non-executable runner files
7. Prints a versioned report with inline remediation commands

If `harness-manifest.json` is absent, it distinguishes a **self-hosted dev repo** (skills
symlinked via `scripts/dev.sh selfhost`, sibling `skills/` source present) from a genuine
broken install: the former reports `Mode: self-hosted dev repo` and continues; only the
latter warns and stops.

Install path: `skills/claude-warp-inventory/SKILL.md`

---

### `/claude-warp-retro "slug"`

Retrospective over a loop, goal, or harness (or all). Reads state files and git history —
does not modify any loop/goal files (RETRO.md is the only output).

1. Detects each state file's schema (loop `<!-- state:` header / doc-30 `GOAL.md` / harness
   `features.json`) and reads it accordingly — for a goal it analyses completion + rework,
   not a run series
2. Reads git log for run commits and fix commits in the past 30 days
3. Scans last 10 dated sections for verdict distribution and recurring failures
4. Analyses patterns: what worked, what failed, what caused handoffs/timeouts
5. Appends a dated entry to `RETRO.md` with top 3 concrete improvements
6. Records the retrospective as a `converged` event in the cross-session ledger (see
   `/claude-warp-ledger`) so it is queryable across sessions
7. Prints improvements inline

Install path: `skills/claude-warp-retro/SKILL.md`

---

### `/claude-warp-ledger`

Persistent, cross-session **closure ledger** — the queryable "what happened, in order" half of
closure (COMPETITIVE-FINDINGS gap #3) that a single context window can't hold. A thin wrapper over
the executable `scripts/ledger.sh` (so the behaviour is deterministic and self-testable via
`bash scripts/ledger.sh --self-test`, not re-interpreted from prose).

- **`record`** appends one structured closure event — `bash scripts/ledger.sh record --kind
  <goal|loop|harness> --slug <slug> --event <shipped|surfaced|converged|parked|blocked>
  [--version X.Y.Z] [--verdict …] [--surfaced …] [--note …]`. `--kind/--slug/--event` are required
  (fails closed without them).
- **`query`** reads them back filtered by `--kind/--slug/--event/--since`, rendering a table or
  (with `--raw`) verbatim jsonl for `jq`.

Storage is `.claudewarp/ledger.jsonl` — one JSON object per line, **append-only** (mirrors
converge's ethos, git-merge-friendly). JSON-lines, not a markdown summary, so `query` filters on
structured fields and never greps markdown — the false-negative class `scripts/verifier-lib.sh`
exists to avoid. It is **gitignored by default** (local runtime data, like a log — `/claude-warp-setup`
seeds the ignore line); remove that line to commit the closure history into the repo.

It is **not** the memory system (semantic facts/preferences) and **not** native cross-run loop
state (a loop's run cursor): the ledger logs dated *closure events* across all kinds. **Self-host
safe (P4):** `record` self-creates `.claudewarp/`; `query` over a missing/empty ledger prints
`(ledger empty)` and exits 0 — no manifest required.

**Who records:** `/claude-warp-retro` records automatically after writing `RETRO.md`;
`/claude-warp-release` and `/claude-warp-converge` stay strictly read-only (P2) and only **print** a
ready-to-run `record` command — they never write the ledger themselves.

Install path: `skills/claude-warp-ledger/SKILL.md`

---

### `/claude-warp-sync`

Synchronises the harness against the current Claude Code version.

1. Fetches the Claude Code changelog (cached 24h at `~/.claude/cache/changelog.md`)
2. Scans for evidence that any active component is now native
3. Marks superseded components in `harness-manifest.json`
4. Writes migration notes to `HARNESS_SYNC_LOG.md`
5. Adds deprecation notices to affected skill files
6. Commits if anything changed

Install path: `skills/claude-warp-sync/SKILL.md`

---

### `/claude-warp-update`

Pulls the latest ClaudeWarp skills from GitHub into this project.

1. Reads `harness-manifest.json` for the current installed version
2. Fetches the skills directory listing from the ClaudeWarp GitHub repo
3. For each installed skill: fetches the remote SKILL.md and compares with local
4. Applies updates, installs new skills, and reports orphans (removed upstream)
5. Updates `harness-manifest.json` version and commits

Install path: `skills/claude-warp-update/SKILL.md`

---

### `/claude-warp-sync-research`

Developer-facing tool — scans [ClaudeLoops](https://github.com/lucagattoni/Claude-Loops)
on GitHub for patterns not yet implemented in ClaudeWarp. Run from the ClaudeWarp
source repo, not from installed projects.

1. Runs `/claude-warp-sync` as a preliminary step
2. Fetches the ClaudeLoops topic index and latest news digest from GitHub
3. Fetches the ClaudeWarp skills and templates inventory from GitHub
4. Rates each gap High / Medium / Low
5. Appends findings to `CLAUDE_WARP_UPDATE_LOG.md` and prints a summary

Does not implement anything — surfaces findings only.

Install path: `skills/claude-warp-sync-research/SKILL.md`

---

## Templates

| Template | Used by | Purpose |
|---|---|---|
| `CLAUDE.md.tpl` | `claude-warp-setup` | Base loop engineering context for a project |
| `loop.SKILL.md.tpl` | `claude-warp-new-loop` | Loop skill skeleton: guard → state → work → verify → write → stop |
| `guard.sh.tpl` | `claude-warp-new-loop` | Run-once-per-day / weekday-only guard script |
| `run-headless.sh.tpl` | `claude-warp-new-loop` | Single-agent headless runner with `--max-turns` and `--max-budget-usd` |
| `run-fanout.sh.tpl` | `claude-warp-new-loop` | Parallel fan-out runner: `claude --bg --worktree` per item, git-isolated, polled via `claude agents --json` |
| `trigger.crontab.tpl` | `claude-warp-new-loop` | Reference cron entry (not installed — paste into `crontab -e`) |
| `harness-manifest.json.tpl` | `claude-warp-setup` | Version + components registry |
| `VISION.md.tpl` | `claude-warp-new-harness` | Anchor file: high-level goal and success criteria |
| `AGENTS.md.tpl` | `claude-warp-new-harness` | Anchor file: agent roles and handoff protocol |
| `PROMPT.md.tpl` | `claude-warp-new-harness` | Anchor file: current work unit; edit to re-task the loop |

---

## Loop anatomy

Every loop scaffolded by `/claude-warp-new-loop` follows this phase sequence:

```
Phase 1   — Guard check     prevent duplicate runs
Phase 2   — Load state      read STATE header (last_verdict, consecutive_fails/stagnation,
                            acting_on); recover IN_PROGRESS; claim/skip for multi-loop coordination
Phase 2.5 — Inspect         read every file in SCOPE before editing; log unexpected state
Phase 3   — Do the work     goal-specific logic (expanded by /claude-warp-new-loop)
Phase 3a  — Stagnation       no file changes → stagnation counter; 3 in a row → handoff
Phase 3b  — Verify          self-coverage gate (every SCOPE item has a check), then weighted checks
Phase 3c  — Checker         invoke <slug>-checker agent if present (DOER/CHECKER, cross-model)
Phase 4   — Write results   update STATE header; append dated entry; commit
Stopping condition          six-state verdict: pass/skip/fail/handoff/timeout/stopped
```

Every harness scaffolded by `/claude-warp-new-harness` follows this flow:

```
Initializer (once)  →  features.json populated (tasks + wave/depends_on)
Approval gate       →  print breakdown → STOP for review (R2+, or --approve-plan);
                       proceeds once --plan-approved
Runner loop         →  coding agent invoked per pending task (waves run in order;
                       --parallel-waves runs a wave's tasks concurrently)
Coding agent        →  reads session-init → executes one task → commits → stops
```

---

## Developing ClaudeWarp

`scripts/dev.sh` is the developer tool for working on the harness itself (not installed into
consumer projects):

| Command | What it does |
|---|---|
| `scripts/dev.sh selfhost` | Symlinks every skill into `.claude/skills/` so they run as live `/claude-warp-*` commands **in this repo** (next session). Single source of truth — editing `skills/X` updates the live command; symlinks are gitignored so the repo stays a pure distribution source. |
| `scripts/dev.sh unhost` | Removes those symlinks. |
| `scripts/dev.sh verify` | Seven deterministic checks (no LLM, no tokens): source integrity, the setup-is-dynamic regression guard, the install copy contract, setup-template placeholder fill, docs coherence, the shared-executable self-tests (`verifier-lib.sh` + `ledger.sh` + `reviewer-guard.sh` each run their own `--self-test`), and behavioural-claim count coherence (the `M/N` verified-live count is computed from the registry and asserted identical in `BEHAVIOURAL-CLAIMS.md` and this doc). Exits non-zero on failure — suitable for CI. |
| `scripts/dev.sh verify --live` | Additionally runs the real `/claude-warp-setup` (`claude -p`) into a throwaway repo for full fidelity. Costs tokens; opt-in. |

The non-`--live` `verify` runs in CI on every PR and on push to `main` (`.github/workflows/verify.yml`), so the seven deterministic checks gate merges automatically.

**Self-host safety.** Every skill is safe to run in this self-hosted repo (which has no
`harness-manifest.json`): the scaffolders (`new-loop`/`new-goal`/`new-harness`/`new-agent`)
skip manifest registration when it is absent (the artifact still works; `inventory` finds it by
scanning), `/claude-warp-sync` no-ops with "nothing to sync", and `/claude-warp-update`
**refuses** to run (it would overwrite the symlinks with GitHub copies — edit `skills/` directly
instead). So you can `/claude-warp-contract` a plan and let it scaffold here without
`--no-scaffold` if you actually want the artifacts.

**Scope of `verify`:** it checks source integrity and the install *copy contract* — it cannot
reproduce the LLM behaviour of `/claude-warp-setup` itself (that is non-deterministic). Use
`--live` when you need to exercise the actual setup skill end to end.

### Writing per-PR verifiers: `scripts/verifier-lib.sh`

Each implementation batch carries an independent verifier (kept gitignored in `working/`, e.g.
`working/pr7-verify.sh`) that asserts the change landed. These verifiers grep the changed files —
and grepping markdown is where they kept failing. The same **false-negative** bit four consecutive
PRs: a phrase the verifier *correctly* asserted was present, but raw `grep` missed it because
markdown had split or decorated the phrase — `**bold**` markers between words, an `inline code`
span, or a prose line **soft-wrapped** across two physical lines so the multi-word pattern never
matched on a single line. PRs that dodged it only did so by hand-anchoring asserts on short
single-line tokens, which is fragile.

`scripts/verifier-lib.sh` is the shared, tested fix. Source it from a verifier and use the matcher
that fits each assertion:

```bash
source scripts/verifier-lib.sh

chk "release skill exists"        "$(has   '^name: claude-warp-release' skills/claude-warp-release/SKILL.md)"  # structural → raw
chk "documents the no-target case" "$(md_has 'no existing target code'    skills/claude-warp-contract/SKILL.md)" # prose phrase → markdown-aware
```

- **`has <pat> <file>`** — the original raw `grep -qiE` idiom. Use it for structural or
  line-anchored patterns: `^name:`, a SemVer like `^0\.23\.0$`, JSON keys, exact tokens.
- **`md_has <pat> <file>`** — normalizes the file first (strips `` `inline code` ``, `**bold**`
  and `*italic*` asterisk markers **and `_italic_` underscore emphasis**, then joins soft-wrapped
  lines into one whitespace-collapsed stream) before matching. Use it for **prose phrases** that
  markdown may decorate or wrap. Underscore stripping is **boundary-aware** — only a complete
  `_word_` emphasis pair flanked by non-word chars is removed, so `snake_case` identifiers,
  leading-underscore names (`_phase`), and `__dunder__` / `mcp__tool__` runs all survive.
- **`not_has <pat> <file>`** — the **absence** assert (inverse of `has`): echoes `0` when the
  pattern is **absent**, `1` when present. Use it to prove a residual was removed, a placeholder
  filled, or a hint-stripped fixture carries no leak tags — instead of hand-rolling
  `[ "$(has …)" -ne 0 ] && echo 0 || echo 1`. ⚠ Unlike `has`/`md_has` it is **not fail-closed**: over
  a missing file grep finds nothing, so `not_has` reports absent-`0`. It answers *"is this gone?"*,
  not *"does the file exist and lack it?"* — when presence is what matters, use `has`/`md_has`.
- **`chk <label> <rc>`** — the assertion printer; all three matchers echo their exit code so they
  drop straight into `chk "label" "$(...)"`.

**Convention for new verifiers:** every new per-PR verifier should begin with
`source scripts/verifier-lib.sh` and use `md_has` for prose asserts / `has` for structural ones,
rather than redefining a raw-grep `has()`. **`working/pr7-verify.sh` is the reference template.**
(Per-PR verifiers are one-shot gates kept in gitignored `working/`; once a PR merges its scratch
is pruned, with `pr7` retained as the canonical example.)

**`_italic_` gap — closed (v0.28.1):** a phrase split by *underscore* emphasis (`the _alpha_ omega`)
is now reunited by `md_has` via boundary-aware stripping, after the gap had taxed verifier authors on
four consecutive PRs (each hand-anchoring tokens to dodge it). The `--self-test` now asserts the gap
is **closed** (md_has finds the split phrase; raw `has` still misses it) **and** that `snake_case`,
`_phase`, and `__dunder__` runs still survive — so the fix is regression-guarded, not just documented.
Residual edge: two *adjacent* emphasis spans (`_a_ _b_`) may strip only the first — rare in prose;
anchor on a single undecorated token with `has` if you ever hit it.

Both matchers **fail closed**: a match over a missing file yields a non-zero (no-match) result, so
a verifier can never read a NOT-RUN as a pass. The library proves all of this on itself:

```bash
bash scripts/verifier-lib.sh --self-test   # bold / soft-wrap / inline-code defects + the _italic_ known gap
```

The self-test plants each historical defect as a fixture and asserts `md_has` finds the phrase
**while raw `grep` misses it** — so it demonstrates both the fix and the defect it retires — plus a
known-gap pair asserting both matchers miss an `_italic_`-split phrase.

> The shared epistemic-honesty gate `scripts/check-ai-residuals.sh` is already markdown-aware in
> the other direction (it skips code-construct HIGH patterns for `.md`/`.markdown`/`.txt`, so quoted
> sample code in docs doesn't false-*positive*). `verifier-lib.sh` addresses the complementary
> false-*negative* class in the per-PR verifiers.

---

## Prior art & acknowledgements

Several of ClaudeWarp's design decisions were sharpened by studying mature open-source projects that
tackle the same problem — turning a fuzzy intent into a verifiable, closed loop. We adapt their ideas
**critically** (diverging where their assumptions don't hold for an agent-based, budget-governed infra
layer), and credit them here:

| Project | Author | Influenced |
|---|---|---|
| [**PAUL** — *Plan · Apply · Unify Loop*](https://github.com/ChristopherKahler/paul) | Christopher Kahler | Diagnostic failure routing on `--retry` (v0.26.0); per-task acceptance criteria (v0.18.0); the richer `done_with_concerns` / `needs_context` / `blocked` task-status enum |
| [**claude-code-harness** — *CCH TeamAgent Debate*](https://github.com/Chachamaru127/claude-code-harness) | Chachamaru127 | The AI-residuals epistemic-honesty scan (`scripts/check-ai-residuals.sh`); reconcile-and-re-ticket closure (`claude-warp-converge`); the severity→verdict gating honesty rider (v0.28.0); the red-team / Skeptic "try-to-break" reviewer charter + trivially-passing-AC check (v0.29.0) |
| [**idea-to-ship-skills**](https://github.com/nelsonwerd/idea-to-ship-skills) | nelsonwerd | The worth-it gate — `success_metric` + `kill_criterion` (contract Phase 1.5, v0.20.0); the epistemic-honesty rule-set ("NOT RUN ≠ pass", v0.17.0); the confidence-capped-by-verified-ratio honesty rider (v0.28.0) |
| [**devils-advocate**](https://github.com/brandonsimpson/devils-advocate) | brandonsimpson | The anti-fabrication rule ("'no blockers' is a valid result") and the "Unverified" set in verdict outputs — honesty riders (v0.28.0); the reasoning-blind reviewer gate — judge the artifact, not the author's defence (v0.29.0) |
| [**llm-council**](https://github.com/karpathy/llm-council) | Andrej Karpathy (→ `/council`) | The anonymized-author rider — blind author identity before ranking another agent's output to remove self-preference bias (v0.28.0); the single fresh-context reviewer pass (no debate loop) in the red-team checker (v0.29.0); the *unanimous ≠ independent* caution behind the same-family-corroboration label (v0.32.0) |
| [**agent-review-panel**](https://github.com/wan-huiyan/agent-review-panel) | wan-huiyan | The control-validation rule in the QA evaluator's red-team charter — *a check that can't fail proves nothing*: a passing `cmd:` must be confirmed to fail on a deliberately broken implementation (v0.29.0); read-only command-verification of checkable predicates (`[CMD_CONFIRMED]`/`[CMD_CONTRADICTED]`) + the static-inference-consensus caution (same-lines agreement ≠ corroboration) in the reproduction pass (v0.32.0) |
| [**/ultrareview**](https://www.shareuhack.com/en/posts/claude-code-pr-review-subagents-guide) | Anthropic (`/code-review ultra`) | Reproduction-required corroboration — a finding counts only if a second pass reproduces it; the `--corroborate` reproduce-before-block gate on the QA evaluator (v0.30.0) |
| [**adversarial-review**](https://github.com/alecnielsen/adversarial-review) · [(ng fork)](https://github.com/ng/adversarial-review) | alecnielsen · ng | Consensus-gating — a finding needs corroboration to count, a solo pass ≠ confirmed; the corroborated-vs-uncorroborated merge-gating PASS (v0.30.0) |
| [**adversarial-review**](https://github.com/robertoecf/adversarial-review) | robertoecf | Provenance tags (`[pass-N / model]` — agreement as N traceable data points, not headcount) and graceful-degradation-loud (a missing corroborator fails loud, never silently treated as corroborated) (v0.30.0) |
| [**adversarial-review**](https://github.com/dementev-dev/adversarial-review) | dementev-dev | The read-only-reviewer integrity guard (`scripts/reviewer-guard.sh`) — `git status --porcelain` + content-digest snapshot before/after a spawned review pass, hard-stop-loud on any mutation, proving the reviewer was truly read-only (v0.32.0) |
| [**spec-kit**](https://github.com/github/spec-kit) | GitHub | The standing project constitution (`.claudewarp/constitution.md`, v0.17.0); plan-vs-actual reconciliation (`/converge`, v0.19.0) |

Beyond the projects above, the command-verification discipline (v0.32.0) draws research grounding from
**NABAOS / "tool receipts"** ([arXiv 2603.10060](https://arxiv.org/abs/2603.10060)) — distinguishing what a
reviewer *observed* (a command's output) from what it *inferred* — and from the recall-vs-precision
**find/verify** framing of the /ultrareview ecosystem (pass-1 finds; pass-2 verifies by executing).

Where a specific mechanism is borrowed, the relevant skill or doc names its source inline (for
example, the `--retry` routing above credits PAUL's `apply-phase.md`). ClaudeWarp's own framing —
the two-axis shape × risk (R0–R5) classification, budget governance, independent verifiers, and the
agent/fork execution model — is where it deliberately diverges from each of these.
