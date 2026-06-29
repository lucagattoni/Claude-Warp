# Quick start — your first autonomous task in 10 minutes

This guide assumes **zero** prior knowledge of "loops" or how Claude Code runs unattended. By the end
you'll have run a one-shot task that finishes on its own, then turned it into a recurring one that runs
every morning without you. Copy-paste as you go.

**You need:** Claude Code installed, a terminal, and a git repository to work in. If you haven't
installed ClaudeWarp yet, do that first — [install guide](install.md) (one command).

---

## First, the 60-second mental model

Normally you chat with Claude Code interactively: you type, it answers, you type again. An
**autonomous task** removes you from that back-and-forth — you write down *what you want and how to
know it's done*, and Claude works until it's finished, on its own.

ClaudeWarp gives that idea two shapes:

- A **goal** runs **once** and **stops** when a condition is met. ("Collect every TODO in this repo
  into one file." → done, it stops.)
- A **loop** runs the **same job on a schedule**, again and again. ("Every weekday morning, refresh
  that TODO file and note what changed.")

> A goal *finishes* work. A loop *keeps doing* recurring work. Same idea, different shape — you start
> with a goal, and graduate to a loop when the job is worth repeating.

**How a task actually runs** — three pieces, simplest first:

| Piece | What it is | You'll use it as… |
|---|---|---|
| `claude -p "..."` | Run Claude **once, headless** (no chat window) — it does the job and exits | The one-shot you'll run in Part 1 |
| a **runner script** | `scripts/run-<name>.sh` — wraps `claude -p` with cost/turn caps so it's safe to run unattended | What a loop runs each time |
| a **schedule** | cron / launchd / cloud Routine that calls the runner on a timer | What makes a loop *recurring* (Part 2) |

That's the whole lifecycle: **a prompt → wrapped in a runner → fired by a schedule.** Part 1 uses just
the first piece. Part 2 adds the other two.

---

## Part 1 — A one-shot goal (instant win, no scheduling)

Let's collect every `TODO` / `FIXME` comment in your project into a single `TODOS.md` report. It's
safe (it only reads your code and writes one new file) and it has an obvious "done": the file exists
and lists the TODOs.

### Step 1 — Describe the goal

`/claude-warp-new-goal` turns a one-line description into a bounded, verifiable task:

```bash
claude -p '/claude-warp-new-goal "scan the repository for every TODO and FIXME comment and collect them into TODOS.md, one per line with its file path and line number"'
```

ClaudeWarp scores the goal for readiness (is the objective clear? is "done" checkable?), then writes
two files:

- `<slug>-GOAL.md` — the goal's **state file**: its objective, its done-conditions, and a log it
  updates as it works. This is what lets it pick up where it left off if it's interrupted.
- `scripts/run-<slug>.sh` — a run-once script you can re-invoke.

### Step 2 — Run it

```bash
bash scripts/run-<slug>.sh      # use the slug ClaudeWarp printed, e.g. collect-todos
```

It scans your repo, writes `TODOS.md`, and **stops** — because the done-condition is met. No timer, no
daemon, nothing left running.

### Step 3 — Check the result

```bash
cat TODOS.md
```

That's a complete autonomous task: you described it, it finished it, it stopped. 🎉

> **What just happened?** You didn't write a schedule or a runner by hand — the goal skill generated
> them and ran the work for you. For the readiness scale it scored your goal against, see
> [Goal readiness — G0–G3](goal-readiness.md).

---

## Part 2 — Graduate to a recurring loop (with scheduling)

A one-shot is great once. But "keep the TODO report fresh" is a job worth repeating — that's a
**loop**. A loop adds the two lifecycle pieces from the mental model: a **runner** that's safe to run
unattended, and a **schedule** that fires it.

### Step 1 — Scaffold the loop

```bash
claude -p '/claude-warp-new-loop "every weekday morning, regenerate TODOS.md from the current code and note in the log how many TODOs changed since the last run"'
```

From that one sentence ClaudeWarp derives a schedule, a turn cap, a cost cap, a stop condition, and a
state file, then creates:

| File | What it's for |
|---|---|
| `.claude/skills/<slug>/SKILL.md` | The loop's procedure — guard → load state → do the work → verify → record. Edit Phase 3 to change *what* it does. |
| `scripts/run-<slug>.sh` | The **runner** — wraps `claude -p` with `--max-turns` and `--max-budget-usd` so an unattended run can't run away. |
| `scripts/guard-<slug>.sh` | Stops it running twice in one day. |
| `<SLUG>_LOG.md` | Append-only history — what it did each morning. |
| `scripts/trigger-<slug>.crontab` | A ready-to-paste cron line for Step 3. |

### Step 2 — Run it once by hand first

Always test a loop manually before putting it on a timer:

```bash
bash scripts/run-<slug>.sh
cat <SLUG>_LOG.md      # the runner appended an entry describing this run
```

If that looks right, schedule it.

### Step 3 — Put it on a schedule

**Cloud-hosted (preferred)** — runs on Anthropic's infrastructure, no machine of yours needs to be on:

```bash
claude -p "/schedule"
```

**Or local cron** — paste the snippet ClaudeWarp generated:

```bash
crontab -e
# paste the contents of scripts/trigger-<slug>.crontab, save, and exit
```

That's it — the loop now refreshes your TODO report every weekday morning and logs what changed. The
full menu of scheduling options (launchd, webhooks, GitHub events) is in the
[scheduling guide](guides/scheduling.md).

> **Before scheduling anything that *writes* unattended,** decide how much it may do without you —
> see [Deployment posture](guides/deployment.md). Our example only rewrites one report file, so it's
> low-risk; a loop that touches production needs tighter boundaries.

---

## Where to go next

- **Not sure whether you want a goal, a loop, or something bigger?** Let the contract decide for you:
  `claude -p '/claude-warp-contract "describe what you want"'` — it interviews you, classifies the
  shape, and scales its questions to the risk. See [Concepts](concepts.md) for the model behind it.
- **Want to watch a running loop or keep the harness current?** [Monitoring guide](guides/monitoring.md).
- **Want to improve a loop after a few runs?** [Iterating guide](guides/iterating.md).
- **Want the full per-skill reference?** [Skills reference](reference/skills.md).
