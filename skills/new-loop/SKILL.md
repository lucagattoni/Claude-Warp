---
name: new-loop
description: Scaffold a new loop from a one-line goal — creates SKILL.md, guard script, headless runner, state file, and trigger snippet
---

Scaffold a new Claude Code loop for the goal: `$ARGUMENTS`

## Phase 1 — Understand the goal

Parse `$ARGUMENTS` as a plain-English goal description.
Derive from it:
- `SKILL_NAME` — human-readable name (e.g. "Daily dependency audit")
- `SKILL_SLUG` — kebab-case CLI name (e.g. `daily-dep-audit`)
- `SKILL_DESCRIPTION` — one sentence describing what the loop does
- `STATE_FILE` — suggested tracking file name (e.g. `DEP_AUDIT_LOG.md`)
- `DEFAULT_SCHEDULE` — suggested cron schedule (e.g. `0 9 * * 1-5` for weekday 09:00 UTC)
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

Read `templates/run-headless.sh.tpl` and fill:
- `{{SKILL_NAME}}`, `{{SKILL_SLUG}}`, `{{MAX_TURNS}}`, `{{MAX_BUDGET_USD}}`, `{{ALLOWED_TOOLS}}`

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
