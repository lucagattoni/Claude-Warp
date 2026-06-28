---
name: claude-warp-contract
description: The single entry point — start here to automate anything. Interactively specifies a plan (draft-first, risk-classified, critically reviewed), auto-routes to its execution shape (single-shot goal / loop / harness), scales questions to complexity, and hands off to the right scaffolder. Absorbed the former complexity router.
---

Negotiate a Loop Contract for: `$ARGUMENTS`

If `$ARGUMENTS` is empty, stop and print:
`Usage: /claude-warp-contract "describe what you want to automate" [--no-scaffold]`

This is an **interview**, not a form. The spine is the Job-Description framing
(Claude-Loops doc-27): you are onboarding an employee. Draft a concrete contract,
then argue against it critically — scaling rigor with risk — until no gaps,
ambiguities, or contradictions remain. Default ends by handing the contract to a
scaffolder; `--no-scaffold` stops at the approved contract.

Parse flags from `$ARGUMENTS`: `--no-scaffold` (stop after Phase 9).

---

## Phase 1 — Branch (classify the shape)

If `contract.draft.yaml` exists in the repo root, ask the user whether to
**resume** that draft or start over. If resume: load it and jump to the phase its
`_phase` field records.

Otherwise **classify the execution shape** — this is the router (folded in from the former
`/claude-warp-new`). Assess recurrence, stage count, and scope size:

```
1. Recurring on a schedule or event?
   └─ Yes → kind: loop      six-property Loop Contract (recurring)
2. One-shot, but large / multi-stage — several interdependent pieces that each
   need their own work and span more than one context window?
   └─ Yes → kind: harness   decomposed into subplans = task units (doc-26 factory model)
3. Otherwise: one-shot, fits a single context, one verifiable criterion
   └─       kind: goal       four Goal primitives + GOAL.md (doc-30)
```

**Plan-vs-Shape.** The thing you are specifying is a **plan**; `loop` / `goal` / `harness`
are the **shapes** it can take. A *small* plan is a goal; a *big* plan with subplans is a
harness; a *recurring* plan is a loop. Size and recurrence pick the shape — they are not
separate kinds of input.

Do not classify on recurrence alone: a large non-recurring plan is a **harness**, not a goal.
If genuinely unclear between goal and harness, ask: *"Is this one focused change with a single
done-condition, or several interdependent pieces that each need their own work?"*

---

## Phase 1.5 — Worth-it gate (fuzzy/greenfield plans only)

Before drafting, decide whether the plan is even worth doing — the "fuzzy intention" front half a
plan deserves when its *worth* is unsettled. This gate scores **worth, not blast radius**, so it is
independent of the R0–R5 risk class.

**Trigger — only for genuinely fuzzy/greenfield requests.** Detect fuzziness from three signals
together: a **vague verb** ("help with", "improve", "do something about"), **no existing target
code** the plan clearly attaches to, and **exploratory framing** ("maybe", "some kind of", "I want
something that…"). A **concrete change** — a refactor, a migration, a defined feature with settled
scope — **skips this gate entirely** and proceeds straight to Phase 2 (do not block a concrete
change; its worth is already decided by the request).

**When it is genuinely ambiguous** whether the request is fuzzy or concrete, **ask one question**:
*"Is this exploratory (you're not sure yet what/whether to build) or settled-scope (you know the
change, you want it executed)?"* — fuzziness is itself a Type-B judgment call; resolve it honestly
rather than guessing. A clearly-concrete request is not interrupted.

**When triggered — honest-advisor pass.** Pressure-test the idea **two-sidedly** (the strongest case
*for* and *against* — do not cheerlead), then force two answers and a verdict:

- `success_metric` — one **measurable** outcome that means this worked (not "users are happy" — a
  number, a behaviour, a checkable state).
- `kill_criterion` — the condition under which you should **not** build this, or should stop.
- `verdict` — `go` | `iterate` | `park`, measured against the metric:
  - **go** — worth doing now; proceed to Phase 2.
  - **iterate** — promising but the metric/scope isn't sharp enough yet; refine with the user, then re-judge.
  - **park** — not worth building now. Write a `steelman` (the strongest *honest* case for it) and
    `flip_evidence` (what would move it park→go), then **stop before Phase 2** and report the parked
    contract. **Do not scaffold and do not write anchor files** on a park.

**Park is an overridable recommendation, not a hard veto.** Surface the park with its steelman +
flip-evidence and stop the automated flow — but if the user, having read it, explicitly says *build
it anyway*, honor that (the gate informs worth; the user keeps the last word). Record the override in
`decision_log` and proceed to Phase 2 with `verdict: go`.

Write the result into the draft's `worth_it` block (schema below). Non-fuzzy plans never populate it.

---

## Phase 2 — Draft-first

**First, read what you're about to change.** Before drafting, identify the files the change will
touch and **read the current source of every one that already exists** — a *modify*, not a new
file. This is **mandatory for every modify at any risk level**: the cost is trivial (you will read
the file to edit it anyway) and it is the cheapest guard against the most expensive negotiation
defect — drafting `action`/`scope` from an *assumption* about what the code does, then discovering
mid-build that the change is already present, differently shaped, or impossible. A *new* file is
exempt (there is nothing to read). Draft from the code, not from your memory of it.

Then draft a **complete** contract, filling every field with your best guess (mark guesses with
`# GUESS`). Draft-first is deliberate: the user reacts to a concrete artifact rather than answering
into a void.

Write it to `contract.draft.yaml` (schema below) with `_phase: 2`.

### Contract schema

```yaml
# contract.yaml
kind: loop | goal
name: <human-readable>
slug: <kebab-case>
risk: R0 | R1 | R2 | R3 | R4 | R5     # final class after Phase 5
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

worth_it:                             # NEW — populated ONLY for fuzzy/greenfield plans (Phase 1.5)
  success_metric: "<one measurable outcome that means this worked>"
  kill_criterion: "<the condition under which we should NOT build this>"
  verdict: go | iterate | park        # park => stop, do not scaffold
  steelman: "<strongest honest case>"      # required when verdict != go
  flip_evidence: "<what would move park→go>"

decision_log:                         # anti intent-debt
  - "<why this approach over the alternative>"
```

For `kind: goal`, drop `trigger`/`report`; the state file materialised in Phase 9 is
`GOAL.md` (doc-30 schema), not the loop anchor files.

The `worth_it` block is **optional and absent by default** — only a plan that entered Phase 1.5
(a fuzzy/greenfield request) carries it. A concrete change has no `worth_it` block, exactly as
before this gate existed (backwards-compatible).

---

## Phase 3 — Risk classify

Score the draft R0–R5 from its `scope` + `action` (doc-04):

| Level | Risk | What it implies |
|---|---|---|
| R0 | Read-only | No verifier required; light rigor |
| R1 | Reversible write | Commit-level evidence |
| R2 | Merge-gated | Independent verifier required |
| R3 | Prod-adjacent | Human review gate + independent verifier |
| R4 | Irreversible (data, secrets) | Explicit human-approval step |
| R5 | Security-critical | SECURITY gate + security-scan hook |

This sets the rigor level for Phases 4 and 6. Derive `autonomy` from risk as in
`new-loop` Phase 1b (≈ R0→L1, R1–R2→L2, R3+→L3).

---

## Phase 4 — Interview

Fill gaps in the draft dynamically. Open by asking the **1–2 most blocking questions**
(usually the done-condition/STOP and SCOPE) so the user resolves the crux up front — these
two gate everything else and are worth surfacing together. After that opening, proceed
**one property at a time**, choosing each next question from the last answer. Do not batch a
fixed questionnaire beyond that opening. Prioritise the most underspecified or highest-risk
property first.

**New persisted file ⇒ settle its lifecycle, not just its format.** When the plan introduces a
file that persists between runs (a ledger, a cache, a state log), the storage crux must resolve
**two** things: the *format* (schema/encoding) **and** the *lifecycle* — is it tracked in git or
gitignored, and who creates it? Deciding format alone leaves the tracked-vs-ignored question to be
discovered at commit time (the v0.24.0 ledger shipped before this was settled, then a blocked
direct-to-main seed surfaced it). Ask both in the same breath.

Rigor scales with the Phase 3 risk class:

| Risk | Interview posture |
|---|---|
| R0 | Light — confirm BUDGET + STOP, move on (aim ≤ 3 questions) |
| R1 | Medium — challenge the STOP condition and what evidence proves it |
| R2 | + insist on an independent verifier |
| R3 | Aggressive — challenge every property; require an escalation gate |
| R4 | + require an explicit human-approval step in the contract |
| R5 | + require a SECURITY gate |

**Depth also scales with shape (size of the plan).** Question count is adaptive, not fixed:
a small **goal** should resolve in ≤ 3 questions; a **loop** sits in the middle; a **harness**
(a big plan) needs the most — you must additionally elicit how it **decomposes into subplans**
(the rough task units) so the handoff to `new-harness` has something to break down. Few
questions for a small plan, many for a big one.

After each answered property, **rewrite `contract.draft.yaml`** (update `_phase`).
This keeps the negotiation resumable and out of one polluted context window.

Use the Job-Description framing to phrase questions: job title & scope (TRIGGER+SCOPE),
deliverables (ACTION+REPORT), hours (schedule), escalation path (surface_conditions),
performance standard (STOP), spending authority (BUDGET).

---

## Phase 5 — Re-classify

Re-score R0–R5 against the **refined** `action`/`scope`. If the class rose, re-enter
Phase 4 for the newly-required properties (e.g. an escalation gate R0 didn't need but R3
does). **Cap re-entry at 2 cycles**; if risk still oscillates, Surface to the user — an
unstable risk class is itself a judgment call. (This command must not contain the
*infinite fix loop* it guards against.)

---

## Phase 6 — Critical pass

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
| Conflicts a constitution MUST? | Governance violation | "Principle `<Pn>` forbids this. Adjust the **contract**, not the principle — amending the constitution is a separate explicit act." |
| Verifier distinguishes not-run from pass? | Verifier theater | "An unrun check is `not run`, never green. Make `stop.check` fail closed when the verifier can't execute." |
| Verifier asserts only tracked paths in git-diff checks? | Vacuous assertion | "A `git diff` against a gitignored/untracked path is always empty — it passes even if the file was rewritten. Assert on tracked paths, or check the file's content directly." |

**Constitution alignment.** If `.claudewarp/constitution.md` exists **and is filled** (any
principle row is no longer the `# UNFILLED` skeleton), validate the contract against every
**MUST** principle. A MUST violation is **non-dilutable** — you may not reinterpret a principle
to make the contract pass; either change the contract or stop and tell the user the principle
blocks it. SHOULD principles are advisory (surface, don't block). If the file is **absent or
still the unfilled skeleton, skip this check entirely** (no behaviour change — self-host safe).

**Epistemic-honesty residuals.** Before the contract's `stop.check` can certify `done`, the work
must pass `scripts/check-ai-residuals.sh --risk <R>` (advisory R0–R1, blocking R2+). Reference it
in `verifier.mechanism` for R2+ contracts so fake-done residuals can't slip a merge-gated change.

**Subjective STOP (e.g. "improve X"):** do not flat-reject — convert the vibe into a
checkable condition. The primary, general path:

1. **Elicit a concrete deficiency checklist.** From the codebase and your own observation,
   name specific, verifiable weaknesses the goal should fix (e.g. "router doesn't explain its
   choice", "Phase 4 over-questions R0 loops"). Offer them as concrete candidates the user
   selects from — they react to specifics rather than re-explaining the vibe. Done = every
   selected item implemented AND an automated check (tests / `verify` script / exit code) passes.

2. **Special case — design/UX goals** ("improve the UI"): use doc-04's four-dimension gradable
   conversion (Quality / Originality / Craft / Functionality) to turn aesthetics into measurable
   criteria.

Either way, the result must be a `stop.check` that is a command or a binary checklist, not a
feeling. If the user can't yet name what "improved" means, say so plainly and derive it with
them before approving — a contract cannot pass the readiness gate on a vibe.

---

## Phase 7 — Readiness gate

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
Phase 4.

**Worth-it gate (only for plans that entered Phase 1.5).** If the plan carries a `worth_it` block,
it cannot reach Approve unless `success_metric` and `kill_criterion` are both non-empty **and**
`worth_it.verdict == go`. A `park` or `iterate` verdict fails the readiness gate — a parked plan is
reported and **not scaffolded** (unless the user explicitly overrode the park; see Phase 1.5). Plans
that never entered the gate have no `worth_it` block and this point is a no-op for them.

**Constitution gate (both branches, non-dilutable).** If a filled `.claudewarp/constitution.md`
exists, a contract that violates any **MUST** principle **fails the readiness gate regardless of
its G/LCR score** — it cannot be approved until the contract is changed to comply (or the user
amends the constitution as a separate explicit act). This gate is not scaled down by low risk: an
R0 read-only loop that violates a MUST still fails. Absent or unfilled constitution ⇒ gate is a
no-op.

---

## Phase 8 — Approve

Print the final contract in full and require explicit user approval before writing
anything permanent (doc-27 Gate 2). If the user requests changes, return to Phase 4.

---

## Phase 9 — Materialise

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
   - **`kind: harness`** → the decomposition into **subplans** is the harness's task queue, which
     `/claude-warp-new-harness` already produces (its initializer agent). Do **not** decompose here —
     write `contract.yaml` only, and let the handoff (Phase 10) trigger decomposition. (If
     `--no-scaffold`, you may write a first-cut `<slug>-features.json` task list as the decomposition
     artifact so the subplans are captured without scaffolding.)
3. Delete `contract.draft.yaml`.
4. Commit:
   ```bash
   git add contract.yaml VISION.md CLAUDE.md AGENTS.md PROMPT.md GOAL.md 2>/dev/null
   git commit -m "contract(<slug>): approved <kind> contract (risk <R>)"
   ```

If `--no-scaffold`: stop here and print the path to `contract.yaml`.

---

## Phase 10 — Handoff

Invoke the scaffolder with the contract as structured input:

- `kind: loop`     → `/claude-warp-new-loop "<name>" --contract contract.yaml`
- `kind: goal`     → `/claude-warp-new-goal "<name>" --contract contract.yaml`
- `kind: harness`  → `/claude-warp-new-harness "<name>" --contract contract.yaml` — its initializer
  decomposes the plan into subplans (task units); each subplan then runs as its own unit.

For **R5**, also scaffold a security hook on top:
`/claude-warp-new-hook "security scan for <slug>"`.

Do not reproduce the scaffolder's logic here — delegate fully. The harness is how a plan **too
big for one shape** gets decomposed: contract classifies it (Phase 1), `new-harness` breaks it down.

---

## Report

```
Contract negotiated ✓  (<kind>, risk <R>, readiness <LCR or G-score>)

  Contract : contract.yaml
  Anchors  : VISION.md, CLAUDE.md, [AGENTS.md], PROMPT.md   (or GOAL.md)
  Passes   : <N> critical-pass findings resolved

Next: <handoff target, or "run /claude-warp-new-loop --contract ... when ready" if --no-scaffold>
```
