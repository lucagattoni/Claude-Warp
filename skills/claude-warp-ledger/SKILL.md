---
name: claude-warp-ledger
description: Persistent, cross-session closure ledger — appends structured closure events (what shipped, what was surfaced for a human, what a converge pass reconciled) to an append-only .claudewarp/ledger.jsonl, and queries them back filtered by kind/slug/event/date; the queryable "what happened, in order" half of closure that survives across context windows and sessions
---

Record or query a closure event: `$ARGUMENTS`

This skill is a thin wrapper over `scripts/ledger.sh` — **all logic lives in that executable**
so the behaviour is deterministic and self-testable (`bash scripts/ledger.sh --self-test`),
not re-interpreted from prose each run. Parse `$ARGUMENTS` and run the matching command.

## What the ledger is (and is not)

The ledger is a **chronological, append-only log of closure events** across sessions: a goal
*shipped*, a decision *surfaced* to a human, a converge pass *reconciled* a gap, work *parked* or
*blocked*. It is the queryable, cross-session memory of *what happened, in order* — the half of
closure (COMPETITIVE-FINDINGS gap #3) that a single context window cannot hold.

It is deliberately **not**:
- the **memory system** — that stores semantic facts and preferences ("the user prefers X"); the
  ledger stores dated events ("v0.24.0 shipped the ledger on 2026-06-28").
- **native cross-run loop state** — that is a loop's own run cursor; the ledger spans *all* kinds
  (goal/loop/harness) and records closure outcomes, not run bookkeeping.

Keep records scoped to closure events so it never duplicates either.

## Storage

`.claudewarp/ledger.jsonl` — one JSON object per line, **append-only** (never rewritten — mirrors
converge's ethos and stays git-merge-friendly). JSON-lines, not a markdown summary, so `query`
filters on structured fields and never has to grep markdown (the false-negative class
`scripts/verifier-lib.sh` exists to avoid).

Each entry: `ts` (UTC ISO-8601), `kind`, `slug`, `event`, `version`, `verdict`, `surfaced`, `note`.

**Gitignored by default.** The ledger is local runtime data (per-checkout persistence), like a log —
`/claude-warp-setup` adds `.claudewarp/ledger.jsonl` to `.gitignore`. This keeps append-only entries
from colliding across branches; a project that wants the closure history to travel with the repo can
remove that ignore line and commit it (accepting tail-merge conflicts as the trade-off).

## Commands

### `record`

```bash
bash scripts/ledger.sh record --kind <goal|loop|harness> --slug <slug> --event <event> \
     [--version X.Y.Z] [--verdict <verdict>] [--surfaced "<text>"] [--note "<text>"]
```

`--kind`, `--slug`, `--event` are required (the command **fails closed** without them).
Intended `event` vocabulary: `shipped` | `surfaced` | `converged` | `parked` | `blocked`.

### `query`

```bash
bash scripts/ledger.sh query [--kind K] [--slug S] [--event E] [--since YYYY-MM-DD] [--raw]
```

No filters → render the whole ledger as a table (newest last). `--raw` emits matching jsonl
lines verbatim (pipe to `jq`). A missing or empty ledger prints `(ledger empty)` and exits 0.

## Self-host safe (constitution P4)

Works with **no manifest and no prior setup**: `record` creates `.claudewarp/` on first use;
`query` over a missing/empty ledger reports empty and exits 0 rather than erroring. Nothing here
needs a harness manifest to be present.

## Who records

- **`/claude-warp-retro`** records automatically after it writes `RETRO.md` (retro already writes
  files, so this stays within its remit).
- **`/claude-warp-release`** and **`/claude-warp-converge`** stay strictly read-only (constitution
  P2): they **print** a ready-to-run `record` command in their report for the operator to run —
  they never write the ledger themselves.
- Anyone (operator or skill) may `record` an event explicitly.
