# Concepts — Plans, Shapes, and the Contract

The one page that explains *what* ClaudeWarp is built around and *why*. If "goal" vs "plan"
vs "loop" ever feels confusing, read this first.

> **New here?** In one breath: you tell ClaudeWarp *what you want and how to know it's done*; it
> figures out whether that's a one-shot **goal**, a recurring **loop**, or a big multi-stage
> **harness**, and scaffolds the right thing. If you just want to *do* something, the
> [Quick start](quickstart.md) walks one example end to end — this page is the "why it's shaped this
> way" behind it.

> **External references.** Throughout the docs, `§X.Y` points to a section of the
> [Claude-Loops documentation](https://lucagattoni.github.io/Claude-Loops/) — the external
> companion that holds the loop-engineering theory ClaudeWarp implements. For example
> `§2.1` [The Loop Contract](https://lucagattoni.github.io/Claude-Loops/27-loop-contract/).
> ClaudeWarp links to it rather than copying it, so the theory stays in one place.

---

## Plan vs Shape (the core distinction)

Two words cause most of the confusion — "goal" and "plan" — because they sound like
alternatives. **They are not.** There is one model:

- A **plan** is *what you want done*, specified well enough to verify — **any size**, from a
  one-line task to a multi-part initiative. The plan **is** the spec.
- A **shape** is *how that plan runs*. Every plan takes exactly **one** of three shapes.

> **"A goal" is not the opposite of "a plan."** A goal is a *small, single-shot plan*. A plan is
> the spec; goal / loop / harness are the shapes a spec can take.

---

## The three shapes (and their aims)

| Shape | What it is | Its aim | When the plan is… | Artifact |
|---|---|---|---|---|
| **goal** (single-shot) | Runs **once** and stops at a verifiable criterion | Finish a bounded task, verifiably, then stop — no runaway | small, one-and-done | `GOAL.md` ([§2.2](https://lucagattoni.github.io/Claude-Loops/30-goal-engineering/)) |
| **loop** | **Recurs** on a schedule or event | Keep doing recurring work autonomously without you in the loop | recurring | loop skill + state ([§2.1](https://lucagattoni.github.io/Claude-Loops/27-loop-contract/)) |
| **harness** | **Decomposed** into subplans (task units), each its own unit of work | Tackle work too big for one context window by breaking it into subplans | big / multi-stage | `features.json` task queue ([§1.2](https://lucagattoni.github.io/Claude-Loops/26-factory-model/)) |

The size and recurrence of the plan **pick the shape** — they are not separate kinds of input:

- *small* plan → **goal**
- *recurring* plan → **loop**
- *big* plan with subplans → **harness**

You do not choose the shape by hand — `/claude-warp-contract` classifies it for you (below).

**Each shape rides a native Claude Code primitive; the scaffold is what wraps it.** The goal
shape's until-done runtime is native [`/goal`](https://code.claude.com/docs/en/goal) (an
independent evaluator judges the done-condition after every turn) — `GOAL.md`, the G0–G3 gate,
and hard budget caps are what ClaudeWarp adds around it. A recurring need that lives inside an
open session is native [`/loop`](https://code.claude.com/docs/en/scheduled-tasks) — the ClaudeWarp
loop adds the guard, cross-run state, and daemon-free trigger that let it run with **no** session.
And a one-off change you'll supervise interactively is native `/plan` (plan mode) — the contract
below is for plans that must execute *without* you. When the native primitive alone covers the
need, the skills say so and stop rather than scaffolding.

---

## `/claude-warp-contract` — the single entry point

**What it is:** the one command you start with to automate anything. It turns a fuzzy
intention into a complete, verifiable **plan**, then hands that plan to the right scaffolder.

**Why it exists (its aims):** the single largest cause of autonomous-loop failure is not a weak
model — it's an **underspecified plan** (no stopping condition, undocumented intent, scope that
contradicts the action; see [§5.2](https://lucagattoni.github.io/Claude-Loops/17-failure-patterns/)).
So the contract front-loads the rigor *before* any work runs. Its aims, concretely:

1. **Make "done" checkable.** It refuses a vibe ("improve X") and converts it into a `stop.check`
   that is a real command or a binary checklist.
2. **Classify the shape automatically.** It assesses recurrence, stage count, and scope size and
   routes the plan to goal / loop / harness — you don't need to know the difference.
3. **Scale rigor to risk.** A read-only plan clears in ≤3 questions; a prod-adjacent or
   irreversible one is challenged on every property and gated by human approval
   ([§5.1 risk model](https://lucagattoni.github.io/Claude-Loops/04-verification/)).
4. **Critically review the plan** against named failure patterns (over-reach, cost runaway,
   dark factory, …) before approving it.
5. **Decompose what's too big.** A plan that doesn't fit one shape becomes a harness, broken
   into subplans by `/claude-warp-new-harness`.
6. **Gate fuzzy ideas on worth, before scope.** For a genuinely exploratory/greenfield request
   (vague verb, no target code, "maybe / some kind of"), a **worth-it gate** (Phase 1.5) runs first:
   it forces a measurable `success_metric` and a `kill_criterion`, then lands a `go | iterate | park`
   verdict. A `park` is reported with a steelman + what evidence would flip it, and **nothing is
   scaffolded** — but the user keeps the last word and may override. A **concrete change skips the
   gate entirely**; its `worth_it` block is simply absent, exactly as before.

**The framing** (from [§2.1](https://lucagattoni.github.io/Claude-Loops/27-loop-contract/)):
specifying a plan is like writing a **job description** — title and scope, deliverables, working
hours, escalation path, performance standard, spending authority. An agent that has those can act
autonomously without constant supervision.

---

## How it all connects

```
your intention
     │
     ▼
/claude-warp-contract        ← specify the PLAN: interview → draft → risk-classify
     │                          → critical pass → readiness gate → approve
     │  (classifies the SHAPE)
     ├── single-shot ─→ /claude-warp-new-goal      ─→ runs once, stops at the check
     ├── recurring  ─→ /claude-warp-new-loop       ─→ recurs on a trigger
     └── big/staged ─→ /claude-warp-new-harness     ─→ decomposes into subplans, runs each
```

One door (`/claude-warp-contract`), one concept (a **plan**), three shapes it can take.

- Ready to specify safely? See [Goal Readiness — G0–G3](goal-readiness.md) for the scale the
  contract gates on.
- Wondering what this adds over plain Claude Code? See [Reference — vs Native Claude
  Code](reference/comparison.md) for the skill-by-skill side-by-side.
- Want the per-skill reference and architecture? See the [Reference — Skills](reference/skills.md)
  and [Reference — Architecture](reference/architecture.md).
- Just want to run something? Start with the [Quick start](quickstart.md), or the
  [how-to guides](guides/scaffolding.md).
