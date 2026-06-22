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

| ID | Metric | Status |
|---|---|---|
| M1 | `install.sh .` completes < 3 min on a clean project | ⬜ |
| M2 | required-files checklist present (8 items) | ⬜ |
| M3 | `/setup-loop-harness` runs clean on ≥ 2 project types | ⬜ |
| M4 | `/new-loop "goal"` produces runnable loop < 10 min | ⬜ |
| M5 | guard script: skips on "already ran", proceeds otherwise | ⬜ |
| M6 | `CLAUDE.md` has real project name/type, no placeholders | ⬜ |
| M7 | `/harness-sync` flags ≥ 1 known-native component as superseded | ⬜ |
| M8 | `harness-manifest.json` records CC version + sync date | ⬜ |
| M9 | guide covers all 6 steps, self-contained | ⬜ |
| M10 | harness installs cleanly in Claude-Loops; fetch-loop-news unaffected | ⬜ |

**Ready = M1–M10 all ✅.**

## Phases

- [x] Phase 1 — Templates (CLAUDE.md.tpl, loop.SKILL.md.tpl, guard.sh.tpl, run-headless.sh.tpl, trigger.crontab.tpl, harness-manifest.json.tpl)
- [x] Phase 2 — Skills (setup-loop-harness, new-loop, harness-sync)
- [x] Phase 3 — install.sh
- [x] Phase 4 — Docs (loop-harness.md, guide.md, README.md)
- [ ] Phase 5 — Iterate to green (score M1–M10, fix, repeat)
- [ ] Phase 6 — Sign-off (T1: push/PR)
