# converge-fixture — a self-contained tree for the `/converge` dogfood

This directory is a **fixture mini-repo** used by [`../RUNBOOK.md`](../RUNBOOK.md) to dogfood
`/claude-warp-converge` (the v0.19.0 reconcile step). It holds its own `contract.yaml` and a small
source tree so a reviewer can run a `/converge` reconciliation of *this* tree against *this* contract
in isolation — without touching the outer ClaudeWarp repo.

A reviewer is pointed here, given the `/converge` SKILL procedure, and asked to reconcile the present
state of the tree against `contract.yaml`'s intent and report the gaps — **reasoning-blind** (no list
of expected findings). It is **hint-stripped**: nothing here names or tags the gaps; the reviewer must
classify them from the contract + the tree alone (the D2 contamination guard).

Tree:

```
contract.yaml        # goal: add a health endpoint + document it
src/api/health.js    # the endpoint
src/db/schema.sql    # database schema
```
