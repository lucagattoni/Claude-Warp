# {{PROJECT_NAME}}

> Loop engineering harness installed by ClaudeWarp.

## Project

- **Type:** {{PROJECT_TYPE}}
- **Root:** {{REPO_ROOT}}
- **Harness version:** {{HARNESS_VERSION}}

## Loop engineering context

This project uses Claude Code loop engineering patterns. Key principle: you write loops
that prompt Claude autonomously — not one-shot prompts.

The conceptual foundation — paradigms, building blocks, failure modes, verification
patterns — is documented in [Claude-Loops](https://github.com/lucagattoni/Claude-Loops).
When designing a new loop, consult `docs/failure-patterns.md` and `docs/building-blocks.md`
there before writing the SKILL.md.

**Skills available** (invoke with `/skill-name`):
- `/claude-warp-new-loop "goal"` — scaffold a recurring loop (SKILL.md + guard + trigger + state)
- `/claude-warp-new-goal "goal"` — scaffold a one-shot bounded goal (GOAL.md + run-once script); stops when a verifiable criterion is met
- `/claude-warp-new-harness "goal"` — scaffold a two-part harness (initializer + coding agent) for complex multi-stage goals
- `/claude-warp-new-agent "role"` — scaffold a specialized subagent in `.claude/agents/`
- `/claude-warp-new-hook "description"` — scaffold a deterministic hook (verify-before-stop, destructive-block, audit-log)
- `/claude-warp-sync` — re-check Claude Code changelog; prune superseded harness components
- `/claude-warp-update` — pull the latest ClaudeWarp skills from the source repo into this project
- `/claude-warp-sync-research` — scan Claude-Loops for new patterns; implement findings automatically

## Loop conventions

- Every loop skill lives in `.claude/skills/<name>/SKILL.md`
- Every loop has a **stopping condition** defined in its SKILL.md
- Every loop has a **guard script** at `scripts/guard-<name>.sh` (prevents double-runs)
- State that accumulates across runs goes in a dedicated tracking file, never in CLAUDE.md
- Logs go in `logs/` (gitignored)

## Token and context discipline

- **Model default:** use Sonnet for all routine loop work; switch to Opus only for planning phases (initializer agents, `/claude-warp-new-harness` scaffold) where reasoning depth matters
- **Compact early:** trigger `/compact` (or set `autoCompact: true`) at 50% context fill, not 95% — waiting until near-full degrades output quality measurably before compaction fires
- **Thinking token cap:** for reasoning-heavy steps, cap extended thinking at 10k tokens; uncapped thinking on routine work burns budget with no quality gain
- **Read before edit:** never edit a file you haven't read in the current context window — blind edits are the primary source of regression bugs in long-running loops

## Scheduling

External trigger (cron/launchd) → `scripts/run-<name>.sh` → `claude -p "/<name>"`.
See `templates/trigger.crontab.tpl` and `docs/usage.md` for setup instructions.

## Escalation rules

Stop and surface to the user (do not retry) if any of these thresholds are hit:

| Trigger | Threshold |
|---|---|
| Consecutive test/verify failures with no clear fix | 3 in a row |
| Same action blocked by a permission hook | 3 consecutive blocks |
| Estimated or actual cost in a single session | Exceeds $10 |
| Operation is irreversible and destructive | Any (DROP, DELETE without WHERE, push to main/prod) |
| Multiple valid approaches exist with no clear winner | Always — surface the options |

When escalating: log the verdict as `handoff` in the state file, write a
`NEEDS_REVIEW` note explaining what triggered escalation, and stop cleanly.
Do not loop indefinitely trying to resolve an ambiguous or destructive situation.

## Timestamps

All timestamps use local system time — no timezone override:
```bash
date '+%Y-%m-%d %H:%M %Z'
```
