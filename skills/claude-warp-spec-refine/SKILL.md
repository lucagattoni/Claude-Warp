---
name: claude-warp-spec-refine
description: Iteratively refine an underspecified goal into a G3-ready GOAL.md or loop spec via clarifying questions; run before /claude-warp-new-goal or /claude-warp-new-loop when the goal is vague or scores below G2
---

Refine the goal: `$ARGUMENTS`

If `$ARGUMENTS` is empty, stop and print:
`Usage: /claude-warp-spec-refine "rough goal description"`

Use this skill when a goal is too vague for `/claude-warp-new-goal` (would score G0 or G1)
or `/claude-warp-new-loop` (verifier is judgement-based with no exit code check).
It produces a refined, G3-ready spec you can pass directly to those skills.

## Phase 1 — Initial readiness score

Score the goal as written against the G0–G3 readiness criteria:

| Score | Criteria |
|---|---|
| **G0** | No verifiable done condition; objective is ambiguous or contradictory |
| **G1** | Done condition exists but is human-judgement-only; no programmatic check possible |
| **G2** | Programmatic verifier exists but scope or budget are unspecified |
| **G3** | Objective clear, verifier is a command with an exit code, scope and budget defined |

If the goal already scores G3: print "Goal is already G3-ready — pass it directly to /claude-warp-new-goal or /claude-warp-new-loop" and stop.

Record the initial score and which criteria are unmet.

## Phase 2 — Generate clarifying questions

For each unmet criterion, generate one targeted question. Maximum 5 questions per round.

Focus on the most blocking gap first:
1. **Verifier** — "How will we know this is done? Is there a command we can run that exits 0 on success?"
2. **Scope** — "Which files, directories, or systems may this change? What must it never touch?"
3. **Objective** — "What is the single most important outcome — what would make this a success?"
4. **Budget** — "Is there a cost or time limit for this to stay within?"
5. **Done condition** — "What observable state signals completion? (A file, a test passing, an API response?)"

Print the questions and wait for the user's answers.

## Phase 3 — Integrate answers and re-score

Incorporate the user's answers into a refined goal statement.
Re-score against G0–G3. If still below G2: return to Phase 2 with remaining unmet criteria only.
If G2 or G3: proceed to Phase 4.

Maximum 3 rounds of Phase 2→3 before writing the best available spec with a warning.

## Phase 4 — Write the refined spec

Write `<GOAL_SLUG>-spec.md`:

```markdown
# <GOAL_NAME> — Refined Spec

**Readiness:** G<N>
**Refined from:** "<original goal>"
**Rounds:** <N>

## Objective
<one sentence, unambiguous>

## Done condition
<programmatic check — command + expected exit code>

## Scope
- May touch: <list>
- Must not touch: <list>

## Budget
- Max cost: $<N>
- Max turns: <N>

## Remaining ambiguities
<any open questions that couldn't be resolved — if none, omit>
```

## Phase 5 — Suggest next step

Print:
```
Spec refined to G<N> ✓  →  <GOAL_SLUG>-spec.md

Next step:
  /claude-warp-new-goal "<refined objective>"
  or
  /claude-warp-new-loop "<refined objective>"
```

If still below G2: warn that the goal may produce an underperforming loop and suggest
the specific missing criteria to resolve before running.
