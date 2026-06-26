---
name: claude-warp-contract
description: Interactively negotiate a complete, risk-classified Loop Contract (or Goal) with the user — draft-first, dynamically questioned, critically reviewed against known failure patterns — then hand a structured contract to /claude-warp-new-loop or /claude-warp-new-goal. Use when a goal needs proper specification before scaffolding.
---

Negotiate a Loop Contract for: `$ARGUMENTS`

If `$ARGUMENTS` is empty, stop and print:
`Usage: /claude-warp-contract "describe what you want to automate" [--no-scaffold]`

This is an **interview**, not a form. The spine is the Job-Description framing
(Claude-Loops doc-27): you are onboarding an employee. Draft a concrete contract,
then argue against it critically — scaling rigor with risk — until no gaps,
ambiguities, or contradictions remain. Default ends by handing the contract to a
scaffolder; `--no-scaffold` stops at the approved contract.

Parse flags from `$ARGUMENTS`: `--no-scaffold` (stop after Phase 8).

---

## Phase 0 — Branch

If `contract.draft.yaml` exists in the repo root, ask the user whether to
**resume** that draft or start over. If resume: load it and jump to the phase its
`_phase` field records.

Otherwise apply the Goals-vs-Loops decision (doc-30):

```
Does this work recur on a schedule or event?
├── Yes → kind: loop  (six-property Loop Contract)
└── No  → kind: goal  (four Goal primitives + GOAL.md)
```

If genuinely unclear, ask one question: *"Will this run repeatedly on a trigger, or
run once until a result is reached?"*

---

## Phase 1 — Draft-first

Draft a **complete** contract from the goal alone, filling every field with your best
guess (mark guesses with `# GUESS`). Draft-first is deliberate: the user reacts to a
concrete artifact rather than answering into a void.

Write it to `contract.draft.yaml` (schema below) with `_phase: 1`.

### Contract schema

```yaml
# contract.yaml
kind: loop | goal
name: <human-readable>
slug: <kebab-case>
risk: R0 | R1 | R2 | R3 | R4 | R5     # final class after Phase 4
autonomy: L1 | L2 | L3                # loop branch only

trigger:                              # loop branch
  type: cron | event | on-demand
  schedule: "<cron>"                  # if type: cron
  event: "<webhook/CI/file>"          # if type: event

scope:
  may_touch: [<paths/systems>]
  must_not_touch: [<paths/systems>]   # → new-loop DO_NOT

action: <one sentence: what it does each run>

budget:                               # doc-27 2-layer ceiling
  loop_max_usd: <N>
  step_max_budget_usd: <N>
  max_turns: <N>

stop:
  verdict: PASS                       # missing/ambiguous verdict = FAIL
  evidence: required                  # cannot exit without test output / diff
  check: "<command that exits 0 when done>"

verifier:
  independent: true | false           # must be true for R2+
  mechanism: "<test cmd | checker agent | CI>"

surface_conditions:                   # Type B human gates (doc-04) — NOT escalation
  - "<judgment call that must Surface, not auto-resolve>"

escalation:
  after_attempts: <N>                 # attempt cap → handoff

report:                               # loop branch
  on: delta                           # only on new/changed/actionable findings
  to: "<channel/file>"

decision_log:                         # anti intent-debt
  - "<why this approach over the alternative>"
```

For `kind: goal`, drop `trigger`/`report`; the state file materialised in Phase 8 is
`GOAL.md` (doc-30 schema), not the loop anchor files.

---

## Phase 2 — Risk classify

Score the draft R0–R5 from its `scope` + `action` (doc-04):

| Level | Risk | What it implies |
|---|---|---|
| R0 | Read-only | No verifier required; light rigor |
| R1 | Reversible write | Commit-level evidence |
| R2 | Merge-gated | Independent verifier required |
| R3 | Prod-adjacent | Human review gate + independent verifier |
| R4 | Irreversible (data, secrets) | Explicit human-approval step |
| R5 | Security-critical | SECURITY gate + security-scan hook |

This sets the rigor level for Phases 3 and 5. Derive `autonomy` from risk as in
`new-loop` Phase 1b (≈ R0→L1, R1–R2→L2, R3+→L3).

---

## Phase 3 — Interview

Fill gaps in the draft dynamically. Open by asking the **1–2 most blocking questions**
(usually the done-condition/STOP and SCOPE) so the user resolves the crux up front — these
two gate everything else and are worth surfacing together. After that opening, proceed
**one property at a time**, choosing each next question from the last answer. Do not batch a
fixed questionnaire beyond that opening. Prioritise the most underspecified or highest-risk
property first.

Rigor scales with the Phase 2 risk class:

| Risk | Interview posture |
|---|---|
| R0 | Light — confirm BUDGET + STOP, move on (aim ≤ 3 questions) |
| R1 | Medium — challenge the STOP condition and what evidence proves it |
| R2 | + insist on an independent verifier |
| R3 | Aggressive — challenge every property; require an escalation gate |
| R4 | + require an explicit human-approval step in the contract |
| R5 | + require a SECURITY gate |

After each answered property, **rewrite `contract.draft.yaml`** (update `_phase`).
This keeps the negotiation resumable and out of one polluted context window.

Use the Job-Description framing to phrase questions: job title & scope (TRIGGER+SCOPE),
deliverables (ACTION+REPORT), hours (schedule), escalation path (surface_conditions),
performance standard (STOP), spending authority (BUDGET).

---

## Phase 4 — Re-classify

Re-score R0–R5 against the **refined** `action`/`scope`. If the class rose, re-enter
Phase 3 for the newly-required properties (e.g. an escalation gate R0 didn't need but R3
does). **Cap re-entry at 2 cycles**; if risk still oscillates, Surface to the user — an
unstable risk class is itself a judgment call. (This command must not contain the
*infinite fix loop* it guards against.)

---

## Phase 5 — Critical pass

Run every check below against the draft. Surface each conflict with the fix prompt;
push back with intensity matching the risk class. **For R3+, run this as an independent
checker** (a cross-model subagent, not self-review — self-critique is reviewer bias):

```
claude -p '/claude-warp-new-agent "contract-checker: reviews a contract.yaml
against the failure-pattern checklist; raises blocking findings only; uses a different
model than the drafting agent"'
```

| Check | Detects | Fix prompt |
|---|---|---|
| SCOPE ⊇ ACTION writes? | Over-reach | "ACTION commits to `src/` but SCOPE is read-only — which is wrong?" |
| BUDGET present + sane? | Cost runaway | "Every 15 min at $2/run = $192/day. Intended?" |
| STOP is a command, not a vibe? | Verifier theater / no stopping condition | "'Looks done' isn't checkable. What command exits 0 when done?" |
| Independent verifier (R2+)? | Reviewer bias | "The loop can't grade its own work for merge-gated changes." |
| Escalation gate defined (R3+)? | Dark factory | "No human checkpoint on a prod-adjacent loop. Add a Surface condition." |
| TRIGGER has work to do? | Polling loop | "Cron every 5 min with usually nothing to do burns tokens — event trigger?" |
| Type B work routed to human? | Verifier theater | "This decision is a judgment call — it must Surface, not auto-resolve." |
| REPORT only on delta? | Notification fatigue | "Reporting every run trains the team to ignore it. Notify on change only." |
| Attempt cap on failure? | Infinite fix loop | "No cap means it retries forever. Cap at N then handoff." |
| Intent documented? | Intent debt | "Why this approach over the alternative? Record it in `decision_log`." |

**Subjective STOP (e.g. "improve X"):** do not flat-reject — convert the vibe into a
checkable condition. The primary, general path:

1. **Elicit a concrete deficiency checklist.** From the codebase and your own observation,
   name specific, verifiable weaknesses the goal should fix (e.g. "router doesn't explain its
   choice", "Phase 3 over-questions R0 loops"). Offer them as concrete candidates the user
   selects from — they react to specifics rather than re-explaining the vibe. Done = every
   selected item implemented AND an automated check (tests / `verify` script / exit code) passes.

2. **Special case — design/UX goals** ("improve the UI"): use doc-04's four-dimension gradable
   conversion (Quality / Originality / Craft / Functionality) to turn aesthetics into measurable
   criteria.

Either way, the result must be a `stop.check` that is a command or a binary checklist, not a
feeling. If the user can't yet name what "improved" means, say so plainly and derive it with
them before approving — a contract cannot pass the readiness gate on a vibe.

---

## Phase 6 — Readiness gate

**Goal branch — G0–G3** (doc-30): objective clarity, verifier independence, state file,
budget. Gate: **G2+** (G3 for R3+).

**Loop branch — Loop Contract Readiness (LCR), 6 points:**

| Point | Met when |
|---|---|
| TRIGGER | type + schedule/event defined |
| SCOPE | `may_touch` and `must_not_touch` both populated |
| ACTION | one concrete sentence, consistent with SCOPE writes |
| BUDGET | both budget layers + max_turns set |
| STOP | `check` is a command with an exit code |
| REPORT | delta-only target defined |

Gate: **LCR ≥ 5/6** (L1/L2); **6/6 for R3+/L3**, plus `verifier.independent: true` and
≥ 1 `surface_conditions` entry. Below the gate: name the failing points and return to
Phase 3.

---

## Phase 7 — Approve

Print the final contract in full and require explicit user approval before writing
anything permanent (doc-27 Gate 2). If the user requests changes, return to Phase 3.

---

## Phase 8 — Materialise

Promote the draft to the real artifacts in the repo root. The machine-readable
`contract.yaml` is written for **both** kinds (it is the `--contract` handoff artifact);
the two kinds differ only in what else they project from it:

1. Write `contract.yaml` (drop the `_phase` field). Neutral name — a goal contract is **not**
   written to a loop-named file.
2. Project the kind-specific artifacts:
   - **`kind: loop`** → anchor files: `VISION.md` (objective/name), `CLAUDE.md` additions
     (guardrails = `must_not_touch` + `surface_conditions`), `AGENTS.md` (roles — only if
     multi-agent), `PROMPT.md` (first task).
   - **`kind: goal`** → `<slug>-GOAL.md` (doc-30 schema: objective, done conditions, guardrails,
     verifier, execution log). No loop anchor files.
3. Delete `contract.draft.yaml`.
4. Commit:
   ```bash
   git add contract.yaml VISION.md CLAUDE.md AGENTS.md PROMPT.md GOAL.md 2>/dev/null
   git commit -m "contract(<slug>): approved <kind> contract (risk <R>)"
   ```

If `--no-scaffold`: stop here and print the path to `contract.yaml`.

---

## Phase 9 — Handoff

Invoke the scaffolder with the contract as structured input:

- `kind: loop`  → `/claude-warp-new-loop "<name>" --contract contract.yaml`
- `kind: goal`  → `/claude-warp-new-goal "<name>" --contract contract.yaml`

For **R5**, also scaffold a security hook on top:
`/claude-warp-new-hook "security scan for <slug>"`.

Do not reproduce the scaffolder's logic here — delegate fully.

---

## Report

```
Contract negotiated ✓  (<kind>, risk <R>, readiness <LCR or G-score>)

  Contract : contract.yaml
  Anchors  : VISION.md, CLAUDE.md, [AGENTS.md], PROMPT.md   (or GOAL.md)
  Passes   : <N> critical-pass findings resolved

Next: <handoff target, or "run /claude-warp-new-loop --contract ... when ready" if --no-scaffold>
```
