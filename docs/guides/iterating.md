# Guide — Iterating on a loop

After a run, inspect the output:
```bash
cat <SLUG>_LOG.md
```

To improve the loop, edit `.claude/skills/<slug>/SKILL.md` — specifically Phase 3 ("Do the work") and Phase 3b ("Verify"). The guard prevents double-runs on the same day; to force a re-run during testing, invoke the skill directly:
```bash
claude -p "/<slug>"
```

After a loop has several runs behind it, `/claude-warp-retro "<slug>"` reads its state file and git history and reports what worked, what failed, and the top improvements to make — a structured alternative to reading the log yourself:
```bash
claude -p '/claude-warp-retro "<slug>"'
```

For the phase-by-phase anatomy you're editing, see
[Architecture → Loop anatomy](../reference/architecture.md#loop-anatomy).
