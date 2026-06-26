# Concepts — Plans, Shapes, and the Contract

The one page that explains *what* ClaudeWarp is built around and *why*. If "goal" vs "plan"
vs "loop" ever feels confusing, read this first.

> **External references.** Throughout the docs, `doc-NN` points to the
> [Claude-Loops knowledge base](https://github.com/lucagattoni/Claude-Loops) — the external
> companion repo that holds the loop-engineering theory ClaudeWarp implements. For example
> `doc-27` = [`docs/27-loop-contract.md`](https://github.com/lucagattoni/Claude-Loops/blob/main/docs/27-loop-contract.md).
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
| **goal** (single-shot) | Runs **once** and stops at a verifiable criterion | Finish a bounded task, verifiably, then stop — no runaway | small, one-and-done | `GOAL.md` ([doc-30](https://github.com/lucagattoni/Claude-Loops/blob/main/docs/30-goal-engineering.md)) |
| **loop** | **Recurs** on a schedule or event | Keep doing recurring work autonomously without you in the loop | recurring | loop skill + state ([doc-27](https://github.com/lucagattoni/Claude-Loops/blob/main/docs/27-loop-contract.md)) |
| **harness** | **Decomposed** into subplans (task units), each its own unit of work | Tackle work too big for one context window by breaking it into subplans | big / multi-stage | `features.json` task queue ([doc-26](https://github.com/lucagattoni/Claude-Loops/blob/main/docs/26-factory-model.md)) |

The size and recurrence of the plan **pick the shape** — they are not separate kinds of input:

- *small* plan → **goal**
- *recurring* plan → **loop**
- *big* plan with subplans → **harness**

You do not choose the shape by hand — `/claude-warp-contract` classifies it for you (below).

---

## `/claude-warp-contract` — the single entry point

**What it is:** the one command you start with to automate anything. It turns a fuzzy
intention into a complete, verifiable **plan**, then hands that plan to the right scaffolder.

**Why it exists (its aims):** the single largest cause of autonomous-loop failure is not a weak
model — it's an **underspecified plan** (no stopping condition, undocumented intent, scope that
contradicts the action; see [doc-17](https://github.com/lucagattoni/Claude-Loops/blob/main/docs/17-failure-patterns.md)).
So the contract front-loads the rigor *before* any work runs. Its aims, concretely:

1. **Make "done" checkable.** It refuses a vibe ("improve X") and converts it into a `stop.check`
   that is a real command or a binary checklist.
2. **Classify the shape automatically.** It assesses recurrence, stage count, and scope size and
   routes the plan to goal / loop / harness — you don't need to know the difference.
3. **Scale rigor to risk.** A read-only plan clears in ≤3 questions; a prod-adjacent or
   irreversible one is challenged on every property and gated by human approval
   ([doc-04 risk model](https://github.com/lucagattoni/Claude-Loops/blob/main/docs/04-verification.md)).
4. **Critically review the plan** against named failure patterns (over-reach, cost runaway,
   dark factory, …) before approving it.
5. **Decompose what's too big.** A plan that doesn't fit one shape becomes a harness, broken
   into subplans by `/claude-warp-new-harness`.

**The framing** (from [doc-27](https://github.com/lucagattoni/Claude-Loops/blob/main/docs/27-loop-contract.md)):
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
- Want the per-skill reference and architecture? See [Loop Harness Reference](loop-harness.md).
- Just want to run something? See [Usage](usage.md).
