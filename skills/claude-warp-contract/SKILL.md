---
name: claude-warp-contract
description: The single entry point — start here to automate anything. Interactively specifies a plan (draft-first, risk-classified, critically reviewed), auto-routes to its execution shape (single-shot goal / loop / harness), scales questions to complexity, and hands off to the right scaffolder. Absorbed the former complexity router.
---

Negotiate a Loop Contract for: `$ARGUMENTS`

If `$ARGUMENTS` is empty, stop and print:
`Usage: /claude-warp-contract "describe what you want to automate" [--no-scaffold]`

This is an **interview**, not a form. The spine is the Job-Description framing
(Claude-Loops §2.1): you are onboarding an employee. Draft a concrete contract,
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
   └─ Yes → kind: harness   decomposed into subplans = task units (§1.2 factory model)
3. Otherwise: one-shot, fits a single context, one verifiable criterion
   └─       kind: goal       four Goal primitives + GOAL.md (§2.2)
```

**Plan-vs-Shape.** The thing you are specifying is a **plan**; `loop` / `goal` / `harness`
are the **shapes** it can take. A *small* plan is a goal; a *big* plan with subplans is a
harness; a *recurring* plan is a loop. Size and recurrence pick the shape — they are not
separate kinds of input.

**Contract vs native plan mode.** If the request is a one-off change the user will *watch and
steer interactively* — no unattended execution, no recurrence, no need for a machine-readable
spec another run can consume — native plan mode (`/plan`) already covers it: research, a
reviewed plan, and approval into execution. Say so and stop instead of negotiating a contract.
A contract earns its ceremony when the plan must run **without the user**: risk class, budgets,
`stop.check`, and the `--contract` handoff exist so a headless scaffold can act on it.

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

**Honesty riders on the worth-it verdict.** A `go | iterate | park` call is a high-leverage judgment,
so close it honestly (this only fires for fuzzy plans — a concrete small goal skips Phase 1.5 entirely
and is never taxed):

- **Confidence-capped-by-verified-ratio.** End the verdict with a `confidence: N/10` line and a one-line
  "M of K load-bearing assumptions actually checked against evidence; confidence capped by that ratio."
  A verdict that probed the idea outscores one asserted from a hunch — credit to **idea-to-ship-skills**
  (nelsonwerd).
- **"Unverified" set.** List what the honest-advisor pass did **not** check (market size unconfirmed,
  perf claim untested, dependency assumed available). A `go` reached without naming its blind spots is
  not a confident `go` — credit to **brandonsimpson/devils-advocate** (MIT).

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

budget:                               # §2.1 2-layer ceiling
  loop_max_usd: <N>
  step_max_budget_usd: <N>
  max_turns: <N>

stop:
  verdict: PASS                       # missing/ambiguous verdict = FAIL
  evidence: required                  # cannot exit without test output / diff
  # R2+ (Option 2.5): a merge-gating PASS should be CORROBORATED — reproduced by a second pass or an
  # independent verifier, not a solo green. A single uncorroborated pass is labeled "uncorroborated",
  # never silently counted as full evidence (P6: NOT corroborated ≠ corroborated).
  check: "<command that exits 0 when done>"

verifier:
  independent: true | false           # must be true for R2+
  mechanism: "<test cmd | checker agent | CI>"

validation:                           # plan-quality lenses — scaled by risk (Phase 6)
  mode: not_required_lightweight | native | subagent | manual-pass | unavailable
  lenses:                             # each: ok | "gap: <what>"
    spec_alignment: ok                # action+scope actually serve the stated objective
    memory_reuse: ok                  # not re-solving prior work (ledger / RETRO.md / archive checked)
    product_fit: ok                   # in the project's purpose; no scope-creep
    security_fit: ok                  # no secret / permission / supply-chain exposure
    works_in_practice: ok             # DoD carries its own test / CI / review gate

surface_conditions:                   # Type B human gates (§5.1) — NOT escalation
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
`GOAL.md` (§2.2 schema), not the loop anchor files.

The `worth_it` block is **optional and absent by default** — only a plan that entered Phase 1.5
(a fuzzy/greenfield request) carries it. A concrete change has no `worth_it` block, exactly as
before this gate existed (backwards-compatible).

---

## Phase 3 — Risk classify

Score the draft R0–R5 from its `scope` + `action` (§5.1):

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
claude -p '/claude-warp-new-agent "contract-checker (red-team / Skeptic): tries to
BREAK the contract, not confirm it. Reviews contract.yaml against the failure-pattern
checklist AND asks: which acceptance criteria / stop.check admit a trivially-passing
implementation (an empty stub, a hardcoded value, a check that always exits 0)? which
load-bearing claim does the contract rely on that was assumed, not verified against the
repo? Raises blocking findings only; severity-tags them. REASONING-BLIND: it is given
contract.yaml + the repo, NOT the drafting conversation reasoning — it must judge whether
the contract holds from the artifact alone, not from the author defence of it. Single
fresh-context pass (no debate loop). Uses a different model than the drafting agent."'
```

**Red-team charter (the checker tries to break it).** Beyond the checklist, the checker — and the
in-conversation critical pass below it — must adopt a Skeptic posture: assume the contract is wrong
and look for the way it passes *without doing the work*. The two checks this adds (rows in the table)
are the load-bearing ones; the **reasoning-blind** framing (judge the artifact, not the author's
defence of it) is what keeps the pass from rubber-stamping its own draft. A clean red-team result is
valid — do not manufacture a break (the anti-fabrication rider still binds). A "trivially-passing AC"
that is actually a deliberate human-gated decision **Surfaces** as a Type-B call, never auto-fails.
This charter adapts external prior art (credited in `docs/reference/developing.md` + CHANGELOG): **CCH
TeamAgent Debate** (Chachamaru127) — the Skeptic / try-to-break charter; **brandonsimpson/devils-advocate**
(MIT) — the reasoning-blind independence gate; **Karpathy LLM Council** → **/council** — the
fresh-context, single-round rule (one pass, no debate loop); **agent-review-panel** (wan-huiyan) — the
control-validation idea ("a check that can't fail proves nothing"). Adapt critically: same-model
reasoning-blind neutralises author-bias, not a shared model-family blind spot (that is Option 2.5).

| Check | Detects | Fix prompt |
|---|---|---|
| SCOPE ⊇ ACTION writes? | Over-reach | "ACTION commits to `src/` but SCOPE is read-only — which is wrong?" |
| BUDGET present + sane? | Cost runaway | "Every 15 min at $2/run = $192/day. Intended?" |
| STOP is a command, not a vibe? | Verifier theater / no stopping condition | "'Looks done' isn't checkable. What command exits 0 when done?" |
| AC admits a trivially-passing impl? *(red-team)* | Verifier theater — a `stop.check` an empty stub passes | "Could this `stop.check` exit 0 on an empty or hardcoded implementation? A check that can't fail proves nothing — name the trivial pass, or make the check discriminate." |
| Load-bearing claim verified, not assumed? *(red-team)* | Unproven assumption gates the merge | "Which claim the contract leans on was assumed from memory, not checked against the repo? Verify it against the source, or move it to the `Unverified` set." |
| Independent verifier (R2+)? | Reviewer bias | "The loop can't grade its own work for merge-gated changes." |
| Escalation gate defined (R3+)? | Dark factory | "No human checkpoint on a prod-adjacent loop. Add a Surface condition." |
| TRIGGER has work to do? | Polling loop | "Cron every 5 min with usually nothing to do burns tokens — event trigger?" |
| Type B work routed to human? | Verifier theater | "This decision is a judgment call — it must Surface, not auto-resolve." |
| REPORT only on delta? | Notification fatigue | "Reporting every run trains the team to ignore it. Notify on change only." |
| Attempt cap on failure? | Infinite fix loop | "No cap means it retries forever. Cap at N then handoff." |
| Intent documented? | Intent debt | "Why this approach over the alternative? Record it in `decision_log`." |
| External prior art credited? | Uncredited borrowing | "This adapts an external project/resource. Credit it by **full name + author + link** (and the specific source artifact) where the mechanism lives — docs, the skill, and the changelog — not a bare shorthand. Adapt it **critically**: note where its assumptions don't transfer." |
| Conflicts a constitution MUST? | Governance violation | "Principle `<Pn>` forbids this. Adjust the **contract**, not the principle — amending the constitution is a separate explicit act." |
| Verifier distinguishes not-run from pass? | Verifier theater | "An unrun check is `not run`, never green. Make `stop.check` fail closed when the verifier can't execute." |
| Merge-gating PASS corroborated, not solo (R2+)? | Single-pass blind spot | "At R2+, a lone green is one data point. Should this PASS be reproduced by a second pass / independent verifier before it gates the merge? If a solo pass is accepted, it must be labeled `uncorroborated`, never silently treated as full evidence (Option 2.5)." |
| Verifier asserts only tracked paths in git-diff checks? | Vacuous assertion | "A `git diff` against a gitignored/untracked path is always empty — it passes even if the file was rewritten. Assert on tracked paths, or check the file's content directly." |

**Honesty riders on this pass's own findings.** The checks above are what the critical pass *looks
for*; these riders govern how it *reports*, so the pass can't itself become verifier theater. Two
apply at **all tiers** (free instruction text, no ceremony); three apply at **R2+** (advisory below,
to not tax small R0/R1 goals):

- **Anti-fabrication (all tiers).** "No blockers" is a valid result. Do **not** manufacture findings
  to look thorough — a contract that genuinely passes every check is reported clean, not padded with
  invented concerns. (Mirror of anti-sycophancy: don't rubber-stamp, but don't invent either.)
- **Anonymized-author (all tiers).** When this pass critiques a contract drafted in the same
  conversation — or, at R3+, when the independent checker ranks the drafting agent's output — judge
  the artifact on its merits with the author's identity/reasoning set aside first, to remove
  self-preference bias. Works even same-model: you blind *who wrote it* before deciding if it holds.
- **Severity→verdict gating (R2+).** Tag each finding `critical | major | minor | recommendation`.
  Only **critical/major** block approval (return to Phase 4); **minor/recommendation** are recorded
  in `decision_log` and never stall the contract. Prevents a cosmetic nit from gating a sound change.
- **Confidence-capped-by-verified-ratio (R2+).** End the pass with a `confidence: N/10` line plus a
  one-line tally — "M of K load-bearing checks actually verified against the source; confidence capped
  by that ratio." A pass that read the code scores higher than one reasoning from memory; an unread
  assumption cannot push confidence up.
- **"Unverified" set (R2+).** List every check the pass could **not** actually run (e.g. a `stop.check`
  command not executed here, a path not read). This makes P6 (NOT RUN ≠ pass) visible in the output
  rather than implicit — the reader sees the pass's blind spots, not just its findings.

These riders adapt external prior art, credited where each lives (and in `docs/reference/developing.md` +
CHANGELOG): **CCH TeamAgent Debate** (Chachamaru127) — severity→verdict gating; **idea-to-ship-skills**
(nelsonwerd) — confidence-capped-by-verified-ratio; **Karpathy LLM Council** → **/council** —
anonymized-author; **brandonsimpson/devils-advocate** (MIT) — anti-fabrication + the "Unverified" set.
Adapt critically: severity gating must still route Type-B judgment calls to Surface (never auto-resolve
a `minor` that is actually a hidden judgment call); anonymized-author is same-model here, so it
neutralizes author-bias, not a shared-family blind spot.

**Plan-validation lenses (record `validation.mode`).** Beyond breaking the `stop.check`, validate the
plan is *well-formed* through five fixed lenses, recording the result in the contract's `validation`
block. Pick the **mode** by risk (don't tax small plans): a trivial R0 change is
`not_required_lightweight` (skip the lenses); R1 is `native` (solo, in-conversation); **R2+ is
`subagent`** (an independent perspective — the same independence P2 already wants); R3+ may require
`manual-pass` (a human signs off). If no valid mode is reachable on a plan that needs one, the mode is
`unavailable` and planning **stops** — do not proceed on Required (R1+) planning without a mode.

Run each lens and tag it `ok` or `gap: <what>`:

| Lens | Passes when | How to check it here |
|---|---|---|
| **spec_alignment** | `action` + `scope` actually serve the stated objective (not a near-miss) | compare the draft against the objective |
| **memory_reuse** | this isn't re-solving work already shipped or parked | grep the ledger (`scripts/ledger.sh query`), `RETRO.md`, `archive/` for the slug/topic |
| **product_fit** | it fits the project's purpose; no scope-creep bolted on | weigh against README / constitution scope |
| **security_fit** | no secret / permission / supply-chain / public-repo exposure introduced | tie to the R5 SECURITY gate + `check-ai-residuals` |
| **works_in_practice** | the Definition of Done carries its own test / CI / review gate | `stop.check` is a real command **and** `verifier` is set |

A `gap:` on a load-bearing lens returns to Phase 4 (same as a critical/major finding). `memory_reuse`
and `product_fit` are the two lenses the earlier checks don't already cover — a plan can be internally
consistent yet still duplicate shipped work or quietly widen scope. Adapts **claude-code-harness**'s
`team_validation_mode` (Chachamaru127) — critically: ClaudeWarp scales the mode by its existing R0–R5
risk class rather than a separate trigger, and folds the lenses into the one critical pass instead of a
standalone gate.

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

2. **Special case — design/UX goals** ("improve the UI"): use §5.1's four-dimension gradable
   conversion (Quality / Originality / Craft / Functionality) to turn aesthetics into measurable
   criteria.

Either way, the result must be a `stop.check` that is a command or a binary checklist, not a
feeling. If the user can't yet name what "improved" means, say so plainly and derive it with
them before approving — a contract cannot pass the readiness gate on a vibe.

---

## Phase 7 — Readiness gate

**Goal branch — G0–G3** (§2.2): objective clarity, verifier independence, state file,
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

**Validation-mode gate.** A plan whose risk required the lenses (R1+) cannot Approve with
`validation.mode: unavailable`, nor with a `gap:` still open on a load-bearing lens — an unreachable
validation mode is itself a blocker. Resolve a mode and close the gaps, or Surface to the user. R0
`not_required_lightweight` plans are a no-op here.

**Constitution gate (both branches, non-dilutable).** If a filled `.claudewarp/constitution.md`
exists, a contract that violates any **MUST** principle **fails the readiness gate regardless of
its G/LCR score** — it cannot be approved until the contract is changed to comply (or the user
amends the constitution as a separate explicit act). This gate is not scaled down by low risk: an
R0 read-only loop that violates a MUST still fails. Absent or unfilled constitution ⇒ gate is a
no-op.

---

## Phase 8 — Approve

Print the final contract in full and require explicit user approval before writing
anything permanent (§2.1 Gate 2). If the user requests changes, return to Phase 4.

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
   - **`kind: goal`** → `<slug>-GOAL.md` (§2.2 schema: objective, done conditions, guardrails,
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
