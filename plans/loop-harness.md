# Plan: ClaudeWarp — Loop Harness (self-pruning, native-first)

## Context

Loop engineering needs consistent per-project infrastructure. But Claude Code itself now
provides most of it natively. A harness that re-implements these would be obsolete on
arrival and rot with each Claude Code release.

This plan builds a deliberately thin harness that:
1. Installs only the layer Claude Code does *not* provide
2. Self-prunes: re-reads the Claude Code changelog and flags/removes parts that become native
3. Is installed and maintained by Claude Code itself, as automatically as possible.

## Operating contract

**Autonomy:** Local-only. Everything in-repo runs without asking. Stop only for:
- T1: global `~/.claude/` writes, remote push / PR, OS cron registration
- T2: genuine product-scope judgment calls
- T3: conflicting requirements
- T4: missing access that can't be defaulted

**Scope-cuts:** Auto-cut clearly-redundant components, log the reason. Only ask when
the cut is a real judgment call.

## Metrics (definition of "ready to use")

### Foundation (v0.1.0)

| ID | Metric | Status |
|---|---|---|
| M1 | `install.sh` completes < 5 min on a clean project | ✅ 3:51 |
| M2 | required-files checklist present (8 items) | ✅ all present |
| M3 | `/claude-warp-setup` runs clean on ≥ 2 project types | ✅ generic + node |
| M4 | `/claude-warp-new-loop "goal"` produces runnable loop < 10 min | ✅ 2:55 |
| M5 | guard script: skips on "already ran", proceeds otherwise | ✅ verified both paths |
| M6 | `CLAUDE.md` has real project name/type, no placeholders | ✅ no placeholders |
| M7 | `/claude-warp-sync` flags ≥ 1 known-native component as superseded | ✅ skill-distribution-workaround flagged |
| M8 | `harness-manifest.json` records CC version + sync date | ✅ v2.1.183, local timestamp |
| M9 | docs cover install + usage, self-contained | ✅ install.md + usage.md + loop-harness.md |
| M10 | harness installs cleanly in Claude-Loops; fetch-loop-news unaffected | ⬜ pending |

### Extended capabilities (v0.2.0–v0.5.0)

| ID | Metric | Status |
|---|---|---|
| M11 | `/claude-warp-new-loop` generates runner with `--max-budget-usd` | ✅ run-headless.sh.tpl updated |
| M12 | loop SKILL.md template includes IN_PROGRESS recovery and verifiable stop condition | ✅ loop.SKILL.md.tpl updated |
| M13 | `/claude-warp-new-loop` derives `MAX_BUDGET_USD` and `STOP_CONDITION` in Phase 1 | ✅ |
| M14 | `/claude-warp-new-loop` generates Phase 3b (Verify) with a concrete check command | ✅ |
| M15 | `/claude-warp-new-harness` scaffolds initializer agent + coding agent + session-init + anchor files | ✅ |
| M16 | `/claude-warp-new-agent` creates `.claude/agents/<name>.md` with correct model selection | ✅ |
| M17 | fan-out runner template dispatches parallel agents with concurrency cap | ✅ run-fanout.sh.tpl |
| M18 | anchor file templates (VISION, AGENTS, PROMPT) created by `/claude-warp-new-harness` | ✅ |
| M19 | all skills prefixed `claude-warp-` | ✅ v0.5.0 |
| M20 | `/claude-warp-update` fetches latest skills from GitHub; no local path dependency | ✅ |
| M21 | `/claude-warp-sync-research` fetches Claude-Loops and ClaudeWarp inventory from GitHub | ✅ |
| M22 | `/claude-warp-update` tested end-to-end in an installed project | ⬜ pending |
| M23 | M10 revisited: harness installs cleanly in Claude-Loops with new skill names | ⬜ pending |

**Ready = M1–M21 all ✅, M22–M23 verified.**

## Phases

- [x] Phase 1 — Templates (CLAUDE.md.tpl, loop.SKILL.md.tpl, guard.sh.tpl, run-headless.sh.tpl, trigger.crontab.tpl, harness-manifest.json.tpl)
- [x] Phase 2 — Core skills (claude-warp-setup, claude-warp-new-loop, claude-warp-sync)
- [x] Phase 3 — install.sh
- [x] Phase 4 — Docs (install.md, usage.md, loop-harness.md, README.md)
- [x] Phase 5 — Extended skills (claude-warp-new-harness, claude-warp-new-agent, claude-warp-update, claude-warp-sync-research)
- [x] Phase 6 — Safety & reliability (budget caps, IN_PROGRESS recovery, verifiable stop conditions, verification phase)
- [x] Phase 7 — Templates extended (run-fanout.sh.tpl, VISION.md.tpl, AGENTS.md.tpl, PROMPT.md.tpl)
- [x] Phase 8 — Skill renaming (claude-warp- prefix); remote-first (GitHub API + raw URLs, no local paths)
- [ ] Phase 9 — End-to-end validation (M10/M23: install in Claude-Loops; M22: test /claude-warp-update in real project)
- [ ] Phase 10 — Sign-off (T1: push/PR)
