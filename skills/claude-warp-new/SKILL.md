---
name: claude-warp-new
description: Complexity router — assess a goal and invoke the right scaffold (new-goal for one-shot, new-loop for recurring, new-harness for multi-stage); use this instead of picking a scaffold manually
---

Route the goal `$ARGUMENTS` to the right ClaudeWarp scaffold.

If `$ARGUMENTS` is empty, stop and print:
`Usage: /claude-warp-new "describe what you want to automate"`

## Phase 1 — Assess complexity

Evaluate the goal across three dimensions:

**1. Recurrence**
- Runs once and stops when done → one-shot
- Runs on a schedule or repeatedly → recurring

**2. Stage count**
- Single coherent action per run (summarise, audit, scan, fix one thing) → single-context
- Multiple interdependent stages that together constitute the goal (plan, implement, test, deploy) → multi-stage

**3. Scope size**
- Goal fits in one agent session (≤ ~30 turns) → single-context
- Goal spans multiple sessions or context windows → multi-stage

Apply the routing table:

| Recurrence | Stage count / Scope | → Scaffold | Skill |
|---|---|---|---|
| One-shot | Any | **Goal** | `/claude-warp-new-goal` |
| Recurring | Single-context | **Loop** | `/claude-warp-new-loop` |
| Recurring | Multi-stage | **Harness** | `/claude-warp-new-harness` |

**When in doubt between Loop and Harness:** if the goal can be described as one action
per run ("every morning, do X"), use Loop. If it requires a planner to break it into
tasks first ("implement feature Y across multiple sessions"), use Harness.

## Phase 2 — Confirm routing decision

Print the routing decision before invoking:

```
Routing: <GOAL_SUMMARY>

  Type     : <Goal | Loop | Harness>
  Reason   : <one sentence — which dimension determined the choice>
  Invoking : /<skill>
```

Then invoke the appropriate skill with the original `$ARGUMENTS`:

- **Goal** → invoke `/claude-warp-new-goal "$ARGUMENTS"`
- **Loop** → invoke `/claude-warp-new-loop "$ARGUMENTS"`
- **Harness** → invoke `/claude-warp-new-harness "$ARGUMENTS"`

Do not reproduce the target skill's logic here — delegate fully and let it handle all phases.

## Quick reference

```
/claude-warp-new "migrate auth module to v2"
  → Goal  (one-shot, stops when all /auth tests pass)

/claude-warp-new "summarise new GitHub issues every morning"
  → Loop  (recurring, single context, daily at 09:00)

/claude-warp-new "refactor the payment service across all files"
  → Harness  (recurring until done, multi-stage: plan → implement → verify)
```
