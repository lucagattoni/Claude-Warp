---
name: claude-warp-new-loop
description: Scaffold a new loop from a one-line goal — creates SKILL.md, guard script, headless runner, state file, and trigger snippet
---

Scaffold a new Claude Code loop for the goal: `$ARGUMENTS`

## Phase 1 — Match against known patterns

Before deriving parameters from scratch, check whether the goal matches one of
the seven named loop patterns from the Loop Patterns Catalog. If it matches,
use the pattern's pre-defined parameters as defaults (the user can override).

| Pattern | Matches when goal involves… | Schedule | MAX_BUDGET | Safety rule |
|---|---|---|---|---|
| **Daily Triage** | Morning scan of issues / CI / stale PRs / alerts | `0 9 * * *` | $0.10 | Report only (L1) |
| **PR Babysitter** | Managing PRs through CI and review cycles | `*/15 * * * *` | $0.30 | L2; never force-merge |
| **CI Sweeper** | Reacting to failing CI; auto-fix and push | `*/15 * * * *` | $0.05 | **Mandatory early-exit after 3 fix attempts** |
| **Dependency Sweeper** | Patch vulnerable or outdated packages | `0 */6 * * *` | $0.20 | Patch-only; escalate minor/major bumps |
| **Post-Merge Cleanup** | TODO/dead code cleanup PRs | `0 2 * * *` | $0.10 | Off-peak only; never touch production paths |
| **Changelog Drafter** | Generating changelog from commit history | pre-release | $0.10 | Human review before publish (L1) |
| **Issue Triage** | Labelling and categorising issues | `0 9 * * *` | $0.10 | L1; escalate auto-close to L2 |

If the goal matches a pattern: note which one and use its parameters as the
starting point. Also embed the pattern's **Safety rule** as a hard constraint
in Phase 3 of the generated SKILL.md (e.g. for CI Sweeper: "Stop after 3 fix
attempts — do not loop indefinitely; mark verdict `timeout` and exit").
If no pattern matches: derive all parameters from scratch.

## Phase 1b — Understand the goal

Parse `$ARGUMENTS` as a plain-English goal description.
Derive from it:
- `SKILL_NAME` — human-readable name (e.g. "Daily dependency audit")
- `SKILL_SLUG` — kebab-case CLI name (e.g. `daily-dep-audit`)
- `SKILL_DESCRIPTION` — one sentence describing what the loop does
- `STATE_FILE` — suggested tracking file name (e.g. `DEP_AUDIT_LOG.md`)
- `CRON_SCHEDULE` — suggested cron schedule (e.g. `0 9 * * 1-5` for weekday 09:00)
- `SCOPE` — which files/dirs/APIs the loop may read or write (e.g. `src/`, `GitHub Issues`)
- `ACTION` — one sentence describing what the loop does each run (e.g. "reads open issues, summarises new ones, appends to STATE_FILE")
- `MAX_TURNS` — conservative estimate based on goal complexity (default 30)
- `MAX_BUDGET_USD` — hard cost cap per run; default 2.00; increase only for goals that
  demonstrably require more (complex refactors, large fan-outs)
- `STOP_CONDITION` — one sentence describing a verifiable signal that the loop has
  succeeded (e.g. "all tests pass", "state file contains DONE entry for today",
  "no new items found in source"); must be checkable by reading a file or exit code,
  not just "looks finished"
- `ALLOWED_TOOLS` — minimum tool set needed (default: `"Read,Edit,WebFetch"`)

Get local time:
```bash
date '+%Y-%m-%d %H:%M %Z'
```

## Phase 2 — Create files

**2a. Skill file** — `.claude/skills/<SKILL_SLUG>/SKILL.md`

Read `templates/loop.SKILL.md.tpl` from ClaudeWarp source and fill:
- `{{SKILL_NAME}}`, `{{SKILL_SLUG}}`, `{{SKILL_DESCRIPTION}}`, `{{SKILL_GOAL}}`, `{{STATE_FILE}}`
- `{{CRON_SCHEDULE}}`, `{{SCOPE}}`, `{{ACTION}}`, `{{MAX_BUDGET_USD}}`, `{{MAX_TURNS}}`, `{{STOP_CONDITION}}`
- For fan-out: also fill `{{TASK_LIST_COMMAND}}` and `{{TASK_PROMPT_PREFIX}}`

Expand Phase 3 ("Do the work") based on the goal description — write 3–5 concrete
sub-steps appropriate to the goal. This is the most important customisation.

Expand Phase 3b ("Verify") with the specific check command for this loop. If no
automated check is available, explain what to inspect manually and why no check exists.

Replace the Stopping condition section with the derived `STOP_CONDITION` sentence,
preserving the SUCCESS / SKIP / FAILURE structure from the template.

**2b. Guard script** — `scripts/guard-<SKILL_SLUG>.sh`

Read `templates/guard.sh.tpl` and fill `{{SKILL_NAME}}`, `{{SKILL_SLUG}}`, `{{STATE_FILE}}`.
Make executable:
```bash
chmod +x scripts/guard-<SKILL_SLUG>.sh
```

**2c. Headless runner** — `scripts/run-<SKILL_SLUG>.sh`

If the goal processes a **single context per run** (the common case):
read `templates/run-headless.sh.tpl` and fill:
- `{{SKILL_NAME}}`, `{{SKILL_SLUG}}`, `{{MAX_TURNS}}`, `{{MAX_BUDGET_USD}}`, `{{ALLOWED_TOOLS}}`

If the goal processes **many independent items in parallel** (batch migrations,
multi-file ops, fan-out analyses):
read `templates/run-fanout.sh.tpl` instead and fill:
- `{{SKILL_NAME}}`, `{{SKILL_SLUG}}`, `{{MAX_TURNS}}`, `{{MAX_BUDGET_USD}}`, `{{ALLOWED_TOOLS}}`
- `{{TASK_LIST_COMMAND}}` — command that outputs one item per line (e.g. `find src -name "*.py"`)
- `{{TASK_PROMPT_PREFIX}}` — prompt prefix passed to each agent (e.g. `"Migrate this file to async/await:"`)

The fan-out runner uses `claude --bg --worktree` — each item runs in a background
agent with an isolated git worktree; no concurrency cap or manual PID management needed.

Make executable:
```bash
chmod +x scripts/run-<SKILL_SLUG>.sh
```

**2d. State file stub** — `<STATE_FILE>`

Create the state file with a minimal header:
```markdown
# <SKILL_NAME> Log

Append-only run log. Updated by `/<SKILL_SLUG>` each run.

---
```

**2e. Trigger snippet** — `scripts/trigger-<SKILL_SLUG>.crontab`

Read `templates/trigger.crontab.tpl` and fill:
- `{{SKILL_NAME}}`, `{{SKILL_SLUG}}`, `{{CRON_SCHEDULE}}`, `{{REPO_ROOT}}`

(File is not installed — it is a reference snippet the user pastes into crontab.)

## Phase 3 — Register loop in manifest

Read `harness-manifest.json`. Append to the `loops` array:
```json
{
  "slug": "<SKILL_SLUG>",
  "name": "<SKILL_NAME>",
  "state_file": "<STATE_FILE>",
  "created_at": "<LOCAL_TIMESTAMP>"
}
```
Write back.

## Phase 4 — Commit

```bash
git add .claude/skills/<SKILL_SLUG>/ scripts/guard-<SKILL_SLUG>.sh \
        scripts/run-<SKILL_SLUG>.sh scripts/trigger-<SKILL_SLUG>.crontab \
        <STATE_FILE> harness-manifest.json
git commit -m "feat(loop): scaffold <SKILL_SLUG>"
```

## Phase 5 — Report

```
Loop scaffolded ✓

  Skill   : .claude/skills/<SKILL_SLUG>/SKILL.md
  Guard   : scripts/guard-<SKILL_SLUG>.sh
  Runner  : scripts/run-<SKILL_SLUG>.sh
  State   : <STATE_FILE>

To run interactively : /<SKILL_SLUG>
To run headlessly    : bash scripts/run-<SKILL_SLUG>.sh

To schedule (paste into crontab -e):
<contents of trigger snippet>

To run on weekends too: edit scripts/guard-<SKILL_SLUG>.sh and
comment out the weekday guard block.
```
