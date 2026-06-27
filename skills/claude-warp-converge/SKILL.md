---
name: claude-warp-converge
description: Reconcile actual repo state against a contract's intent and a harness task list, classify every gap (missing/partial/contradicts/unrequested), and append-only re-ticket the unmet pieces — instead of silently retrying or declaring done
---

Reconcile-and-re-ticket closure step for: `$ARGUMENTS`

Run this **after** a harness (or a contract-driven goal) has executed, to answer one question
honestly: *does the actual repo state satisfy the intent, and if not, exactly what is left?*
Converge does not retry blindly and does not declare victory — it **assesses**, **classifies**,
and **re-tickets**.

**This skill is READ-ONLY of the source tree.** Its only write is an **append** to the harness
feature list (never the source, never existing tasks). For a one-shot goal it writes nothing —
it reports. It is a *reconciler*, **not a diff tool**: it judges the present state of the tree
against intent, not the delta of the last commit.

## Inputs

Parse `$ARGUMENTS` for an optional `--slug <slug>` (the harness whose `<slug>-features.json` to
reconcile) and an optional `--contract <path>` (default `contract.yaml`). If neither a contract
nor a feature list is present, print `nothing to converge — no contract.yaml or features.json`
and stop (self-host safe: no manifest required).

Determine the **kind**:
- A `<slug>-features.json` exists → **harness mode** (append-only re-ticketing).
- Only a `*-GOAL.md` / `contract.yaml` of `kind: goal` → **goal mode** (report only).

## Phase 1 — Load intent (read-only)

Read, without modifying:
- `contract.yaml` — `action`, `stop.check`, `scope.may_touch` / `scope.must_not_touch`,
  `verifier`, `risk`, and any `surface_conditions`.
- `<slug>-features.json` (harness mode) — every task, its `status`, `files_in_scope`, and its
  `acceptance` array (PR2) when present. **If a task carries no `acceptance`, fall back to the
  contract-level `action` + `stop.check` as the intent for that task** (graceful degradation when
  PR2 fields are absent).

The union of these is the **intent set**: each item is a piece of promised behaviour with a
`source_ref` you can name (e.g. `stop.check`, `scope.may_touch:src/auth`, `task:7`,
`task:7.acceptance[1]`).

## Phase 2 — Assess code state (read-only, bounded)

Assess the **present state of the tree** against the intent set. Bound the assessment to
`scope.may_touch` plus the files named in tasks' `files_in_scope` — do not wander the whole repo,
and do not inspect a git diff (the question is "is the intent satisfied *now*", not "what changed
last commit").

Use a **hybrid** assessment — mechanical first, judgment only where machines are blind:

1. **Mechanical (grounded).** For every intent item backed by a check — a task `acceptance`
   entry starting `cmd:`, or the contract `stop.check` — **run the command** and record the exit
   code and output. Exit 0 = that item is satisfied. A check you could not run is **`not run`**,
   never a pass (NOT RUN ≠ pass). This pass yields `missing` / `partial` findings on solid ground.
2. **Judgment (only for what no check can see).** Read the in-scope files and reason about the two
   gap-types a checker cannot detect:
   - **`unrequested`** — work present in the tree that no intent item asked for (scope creep).
   - **`contradicts`** — state that violates a `must_not_touch` path or a guardrail/`surface_condition`.
   State one line of evidence per finding. "I did not see a problem" is **not** "there is no problem"
   (not_observed ≠ absent) — point at the proof, or record it as `not run`.

## Phase 3 — Classify each gap

For every intent item **not** satisfied, emit a gap with:

| Field | Values | Meaning |
|---|---|---|
| `gap_type` | `missing` | intent item has no implementation at all |
| | `partial` | started but its `acceptance` / `stop.check` does not pass |
| | `contradicts` | actual state violates a `must_not_touch` / guardrail |
| | `unrequested` | present in the tree but traces to no intent item |
| `source_ref` | e.g. `stop.check`, `task:7.acceptance[1]`, `scope.must_not_touch:secrets/**` | the intent it traces to |
| `severity` | `R0`–`R5` | reuse the risk lens — a `contradicts` on a `must_not_touch` path or a security/R4–R5 guardrail is **top severity** |

## Phase 4 — Append-only write (harness) / report (goal)

**Harness mode — append-only re-ticketing.**

- If there are **no** gaps: leave `<slug>-features.json` **byte-for-byte unchanged** and print
  `✅ converged — actual state satisfies intent`. Do not touch the file at all (idempotency
  depends on this — an unchanged file means a re-run is a no-op).
- If there are gaps, **append** a new `convergence` wave. For each gap add one task:
  ```json
  {
    "id": <next free id — never reuse or renumber>,
    "title": "<gap as an actionable task>",
    "description": "<what to implement to close the gap>",
    "files_in_scope": ["<from source_ref / intent item>"],
    "depends_on": [],
    "wave": <max(existing wave) + 1>,
    "origin": "convergence",
    "gap_type": "missing | partial | contradicts | unrequested",
    "source_ref": "<traceable intent ref>",
    "status": "pending",
    "result": null
  }
  ```
  **Never** rewrite, renumber, or delete an existing task. Appending is the only mutation.

- **Idempotency.** A task already tagged `origin: "convergence"` is *evidence of intent*, not a
  gap — when re-assessing, treat its target as already-ticketed and do not append a duplicate. A
  second converge pass after the convergence wave completes therefore finds nothing new and reports
  `converged`.

- **Surface, do not auto-append, on severe contradictions.** A `contradicts` finding on a
  `must_not_touch` path, or any gap at severity **R4/R5** (or against a guardrail / `surface_condition`),
  is a **Type-B judgment call** — do **not** silently append-and-run it. Print it under a
  `⚠ SURFACE` heading and stop for a human decision. (Lower-severity `missing`/`partial`/`unrequested`
  gaps append normally.)

**Goal mode — report only.** A goal is one-shot; converge does **not** mutate `*-GOAL.md`. Print the
gap report, and for each gap print a ready-to-run follow-up command:
```
/claude-warp-new-goal "<gap title> — closes <source_ref>"
```
The operator decides whether to spin up the follow-up goal.

## Phase 5 — Report

```
Converge (<harness|goal> <slug>) — risk <R>

  Intent items : <N>   satisfied: <S>   not run: <U>
  Gaps         : missing <m> · partial <p> · contradicts <c> · unrequested <x>
  Action       : <appended <k> tasks as wave <W> | byte-for-byte unchanged — converged | report only>
  ⚠ Surfaced   : <severe contradictions held for human decision, or "none">
```

Print the appended task ids (or the goal-mode follow-up commands) so the operator can act without
re-reading the file.

## Notes

- **Read-only of source.** Converge never edits source files — it only *appends* to the harness
  feature list (or reports, in goal mode). If you find yourself wanting to fix code here, stop:
  that is a *task*, and the point of converge is to **ticket** it, not do it.
- **Self-host safe.** Runs with no `harness-manifest.json`. With no contract and no feature list it
  is a no-op. It is invoked explicitly, or by the `new-harness` runner's optional `--converge` tail
  (default off) — never automatically.
