# Plan: `/claude-warp-contract` — Interactive Loop Contract Negotiation

## Context

ClaudeWarp can scaffold loops, goals, and harnesses, but the *quality of the input*
is left to the user. `/claude-warp-new-loop "goal"` guesses six contract properties
from a one-line string; `/claude-warp-new-goal` scores readiness only after the fact.
Underspecified input is the single largest cause of autonomous-loop failure
(doc-17: *intent debt*, *no stopping condition*, *dark factory*, *cost runaway*).

This command moves the rigor **before** scaffolding: an interactive, step-by-step
negotiation between user and Claude that produces a complete, coherence-checked,
risk-classified **Loop Contract** (doc-27) — materialised as anchor files — and then
hands a structured artifact to the existing scaffolders instead of a guessed string.

The spine is doc-27's **Job-Description framing**: the user is onboarding an employee,
not filling a form. Claude interviews dynamically, drafts a contract, and argues
against it critically until no gaps, ambiguities, or contradictions remain.

## Source grounding (Claude-Loops)

| Concept | Doc | Role in this command |
|---|---|---|
| Six contract properties (TRIGGER/SCOPE/ACTION/BUDGET/STOP/REPORT) | 27 | The skeleton of the contract |
| Job-Description framing | 27 | The interview structure |
| Two Quality Gates (evidence completeness, stopping-condition clarity) | 27 | Approval preconditions |
| Anchor File pattern (VISION/CLAUDE/AGENTS/PROMPT) | 27 | The materialised output |
| Type A vs Type B work | 04 | Separates auto-verifiable from human-gated |
| R0–R5 risk classification | 04 | Drives **adaptive** rigor + escalation requirements |
| Six-verdict taxonomy + "Surface" | 04 | What the resulting loop emits; informs STOP |
| Failure-pattern catalog | 17 | The concrete checklist for the critical pass |
| G0–G3 goal readiness | 30 | The readiness gate (Goal branch) |
| Goals-vs-Loops decision | 30 | The branch point in the interview |
| Human-in-the-loop thresholds | 14 | Default escalation gates by risk |

## Locked design decisions

1. **Output model: Option A + `--no-scaffold`.** Default: interview → critical pass →
   readiness gate → auto-handoff to `/claude-warp-new-loop` or `/claude-warp-new-goal`.
   `--no-scaffold` stops at the approved contract (anchor files + YAML) for reuse.
   Rationale: respects the thin-harness principle (no scaffolding duplication); upgrades
   the existing skills to consume a structured contract instead of a guessed string.

2. **Adaptive rigor by R0–R5.** Devil's-advocate intensity scales with risk:
   - R0 (read-only): light — confirm BUDGET + STOP, move on
   - R1 (reversible write): medium — challenge STOP condition and evidence
   - R2 (merge-gated): + require an independent verifier
   - R3 (prod-adjacent): aggressive — challenge every property; force escalation gate + independent verifier
   - R4 (irreversible): + mandatory explicit human-approval step in the contract
   - R5 (security-critical): + SECURITY gate, route to `/claude-warp-new-hook` security-scan

3. **Covers both Loops and Goals.** Early branch on doc-30's question ("does this work
   recur?"). Recurring → six-property Loop Contract. One-shot → four Goal primitives + GOAL.md.

4. **Absorbs `/claude-warp-spec-refine`.** This command is the richer superset
   (spec-refine only lifts a goal G0→G3; this adds risk, Type A/B, anchor files, adaptive
   rigor, loop coverage). spec-refine is deprecated and removed; the README/docs/router
   point here instead. (spec-refine is one release old — low migration cost.)

5. **Name: `/claude-warp-contract`.**

## Interview flow

```
Phase 0  Branch        Recurring work? → Loop path | one-shot → Goal path.
                       If a draft already exists on disk, offer to resume instead.
Phase 1  Draft-first   Hear the goal; draft a COMPLETE contract with best-guess values.
                       Persist to loop-contract.draft.yaml.
Phase 2  Risk classify Score R0–R5 from the draft's SCOPE + ACTION (sets rigor level).
Phase 3  Interview     Dynamic Q&A — one property at a time, next question chosen from
                       the last answer; fill gaps in the draft. Rewrite the draft after
                       each answered property (resumable; survives a context clear).
Phase 4  Re-classify   Re-score R0–R5 against the *refined* ACTION/SCOPE. If the risk
                       class rose, re-enter Phase 3 for the newly-required properties
                       (e.g. an escalation gate that R0 didn't need but R3 does).
                       Cap re-entry at 2 cycles; if risk is still unstable, Surface to
                       the user — an oscillating risk class is itself a judgment call.
                       (The command must not contain the *infinite fix loop* it guards against.)
Phase 5  Critical pass Run the coherence checklist (below). Surface every conflict; push
                       back adaptively to risk. For R3+, run it as an INDEPENDENT checker
                       agent (cross-model), not self-review — self-critique is reviewer bias.
Phase 6  Readiness     Score the readiness rubric for the branch (below). Gate: Loop needs
                       LCR ≥ 5/6 (≥6/6 for R3+); Goal needs G2+ (G3 for R3+).
Phase 7  Approve       Show the final contract; require explicit user approval (Gate 2).
Phase 8  Materialise   Write anchor files (VISION/CLAUDE/AGENTS/PROMPT) + loop-contract.yaml;
                       remove the .draft.yaml.
Phase 9  Handoff       Unless --no-scaffold: invoke new-loop (recurring) or new-goal
                       (one-shot) with the contract as structured input.
```

**Draft-first is deliberate** (doc-27): the user reacts to a concrete artifact rather
than answering into a void, which avoids accumulating "decision noise."

**Refinement is not mid-task arguing.** doc-27 warns never to argue with an agent
*executing* a task — corrections become decision noise. That rule governs execution,
not specification. Collaboratively refining a contract *before* any work runs is the
correct time to disagree; persisting the draft to disk each phase keeps the negotiation
out of a single polluted context window (doc-17: *context pollution*).

## Critical-pass checklist (Phase 4)

Each maps to a named failure pattern. Run all; the *intensity* of pushback scales with risk.

| Check | Detects (failure pattern) | Fix prompt to user |
|---|---|---|
| SCOPE ⊇ ACTION writes? | *Over-reach* | "ACTION commits to `src/` but SCOPE is read-only — which is wrong?" |
| BUDGET present + sane? | *Cost runaway* | "Every 15 min at $2/run = $192/day. Intended?" |
| STOP is a command, not a vibe? | *Verifier theater / no stopping condition* | "'Looks done' isn't checkable. What command exits 0 when done?" |
| Independent verifier (R2+)? | *Reviewer bias* | "The loop can't grade its own work for merge-gated changes." |
| Escalation gate defined (R3+)? | *Dark factory* | "No human checkpoint on a prod-adjacent loop. Add a Surface condition." |
| TRIGGER has work to do? | *Polling loop* | "Cron every 5 min with usually nothing to do burns tokens — event trigger?" |
| Type B work routed to human? | *Verifier theater* | "This decision is a judgment call — it must Surface, not auto-resolve." |
| REPORT only on delta? | *Notification fatigue* | "Reporting every run trains the team to ignore it. Notify on change only." |
| Attempt cap on failure? | *Infinite fix loop* | "No cap means it retries forever. Cap at N then handoff." |
| Intent documented? | *Intent debt* | "Why this approach over the alternative? Record it in the contract." |

## Output artifacts & contract schema

The `loop-contract.yaml` is the **handoff interface** — the structured input
`new-loop`/`new-goal` consume in place of a guessed string. It must be specified
precisely or C10 cannot be built. Schema:

```yaml
# loop-contract.yaml
kind: loop | goal              # set by Phase 0 branch
name: <human-readable>
slug: <kebab-case>
risk: R0 | R1 | R2 | R3 | R4 | R5     # final class after Phase 4 re-classify
autonomy: L1 | L2 | L3         # loop branch only; maps to new-loop's classifier

trigger:                       # loop branch
  type: cron | event | on-demand
  schedule: "<cron>"           # if type: cron
  event: "<webhook/CI/file>"   # if type: event

scope:
  may_touch: [<paths/systems>]
  must_not_touch: [<paths/systems>]   # → new-loop DO_NOT

action: <one sentence: what it does each run>

budget:                        # doc-27 2-layer ceiling
  loop_max_usd: <N>
  step_max_budget_usd: <N>
  max_turns: <N>

stop:
  verdict: PASS                # missing/ambiguous verdict = FAIL
  evidence: required           # cannot exit without test output / diff
  check: "<command that exits 0 when done>"   # the programmatic STOP

verifier:
  independent: true | false    # required true for R2+
  mechanism: "<test cmd | checker agent | CI>"

surface_conditions:            # Type B human gates (doc-04) — DISTINCT from escalation
  - "<judgment call that must Surface, not auto-resolve>"

escalation:
  after_attempts: <N>          # attempt cap → handoff (doc-04 Surface)

report:
  on: delta                    # only on new/changed/actionable findings
  to: "<channel/file>"

decision_log:                  # anti intent-debt (doc-17)
  - "<why this approach over the alternative>"
```

For the **Goal branch**, `kind: goal` drops `trigger`/`report`, and the materialised
state file is `GOAL.md` (doc-30 schema) instead of the loop anchor files.

Anchor files written alongside: `VISION.md` (objective), `CLAUDE.md` additions
(guardrails + surface_conditions), `AGENTS.md` (roles, multi-agent only), `PROMPT.md`
(first task). The YAML is the source of truth; anchor files are projections of it.

`surface_conditions` vs `escalation.after_attempts` are deliberately separate:
the first is *judgment-gated* work that must never auto-run (Type B); the second is
*retry exhaustion* on Type A work. Collapsing them re-introduces *verifier theater*.

## Readiness rubrics

**Goal branch — G0–G3** (doc-30, unchanged): objective clarity, verifier independence,
state file present, budget defined. Gate: G2+ (G3 for R3+).

**Loop branch — Loop Contract Readiness (LCR), 6 points** (one per property, parallel
to G0–G3):

| Point | Met when |
|---|---|
| TRIGGER | Type + schedule/event defined; not a bare "sometimes" |
| SCOPE | `may_touch` and `must_not_touch` both populated |
| ACTION | One concrete sentence; consistent with SCOPE writes |
| BUDGET | Both budget layers + max_turns set |
| STOP | `check` is a command with an exit code (not a vibe) |
| REPORT | Delta-only target defined |

Gate: **LCR ≥ 5/6** for L1/L2 loops; **6/6 required for R3+ / L3** (plus
`verifier.independent: true` and ≥1 `surface_conditions` entry).

## Changes to existing skills

- `new-loop`: accept an optional `--contract <file>` input; when present, skip Phase 1b
  derivation and read the six properties + DO_NOT + autonomy level from the contract.
- `new-goal`: accept `--contract <file>`; read objective, done-conditions, guardrails, budget.
- `claude-warp-new` (router): when the goal is vague/underspecified, route to
  `/claude-warp-contract` first (replaces the spec-refine pointer).
- Remove `claude-warp-spec-refine`; update README, docs/loop-harness.md, CLAUDE.md.tpl,
  goal-readiness.md cross-links.

## Golden test fixtures

These double as acceptance tests for C2/C3/C5/C6 — each has an expected branch, risk
class, and (where relevant) a contradiction the critical pass must catch.

| # | Goal string | Expect branch | Expect risk | Critical pass must catch |
|---|---|---|---|---|
| F1 | "summarise new GitHub issues every morning" | Loop | R0 | — (clean; finishes in ≤3 Q) |
| F2 | "every 15 min, auto-merge any green PR" | Loop | R3 | missing escalation gate; auto-merge is Type B |
| F3 | "migrate lib/auth to v2; done when /auth tests pass" | Goal | R2 | needs independent verifier |
| F4 | "keep the codebase clean" (read-only) but ACTION "commit fixes" | Loop | R1 | SCOPE/ACTION contradiction (*over-reach*) |
| F5 | "nightly DROP of stale rows in prod DB" | Loop | R4 | irreversible; must force human-approval step |
| F6 | "improve the UI" | Goal | R1 | STOP is a vibe — *don't* flat-reject; offer doc-04's 4-dimension gradable conversion (Quality/Originality/Craft/Functionality), then re-score |

Fixtures live in `plans/contract-fixtures.md` and are replayed during verification.

## Self-application (dogfooding)

This command is a plan-quality engine, so its strongest acceptance test is reflexive:
**running it against its own design goal should reconstruct an equivalent contract.**

The plan you are reading was itself refined by applying the command's methodology to it —
draft → risk-classify → critical pass → readiness gate. That pass found and fixed 8 gaps
(schema undefined, Loop readiness rubric missing, single-shot risk classification,
no draft persistence, self-review bias on high-risk, execution-vs-spec confusion,
no fixtures, no dogfooding test). C13 makes the reflexivity a standing test.

## Changes to existing skills

- `new-loop`: accept an optional `--contract <file>` input; when present, skip Phase 1b
  derivation and read the six properties + DO_NOT + autonomy level from the contract.
- `new-goal`: accept `--contract <file>`; read objective, done-conditions, guardrails, budget.
- `claude-warp-new` (router): when the goal is vague/underspecified, route to
  `/claude-warp-contract` first (replaces the spec-refine pointer).
- Remove `claude-warp-spec-refine`; update README, docs/loop-harness.md, CLAUDE.md.tpl,
  goal-readiness.md cross-links.

## Metrics (definition of "ready")

| ID | Metric | Status |
|---|---|---|
| C1 | `/claude-warp-contract "goal"` runs the full 9-phase flow interactively | ⬜ |
| C2 | Phase 0 branches F1–F6 to the expected Loop/Goal path | ⬜ |
| C3 | Phase 2/4 assign the expected R0–R5 class for F1–F6 | ⬜ |
| C4 | Rigor scales: F1 (R0) finishes in ≤3 questions; F2 (R3) forces an escalation gate | ⬜ |
| C5 | Critical pass catches the seeded contradiction in F4 and the Type-B gap in F2 | ⬜ |
| C6 | Readiness gate rejects F6 (G0) with a clear reason; re-classify (Phase 4) lifts risk when ACTION changes | ⬜ |
| C7 | Approved contract materialises a schema-valid `loop-contract.yaml` + anchor files | ⬜ |
| C8 | Default run hands off and produces a runnable loop/goal end-to-end | ⬜ |
| C9 | `--no-scaffold` stops cleanly at the contract artifact; draft is resumable mid-interview | ⬜ |
| C10 | `new-loop`/`new-goal` consume `--contract` and skip their own derivation | ⬜ |
| C11 | `spec-refine` removed; all references repointed; router updated | ⬜ |
| C12 | docs (loop-harness.md, README, goal-readiness.md) + CHANGELOG updated; release cut | ⬜ |
| C13 | Dogfooding: running the command on its own design goal reconstructs an *equivalent* contract — defined as: same branch, same final risk class, a STOP `check` that is a real command, and LCR/G-score within 1 point of this plan's | ⬜ |

**Ready = C1–C13 all ✅.**

## Out of scope (for this iteration)

- Cross-session learning (`/evolve`, `/reconcile`) — doc-27 governed-learning; separate plan.
- Gate Feedback Injection at runtime — belongs to the runner, not contract setup.
- Event-modeling slice decomposition — that's harness territory (`new-harness`).
