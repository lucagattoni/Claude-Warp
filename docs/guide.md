# ClaudeWarp — Setup Guide

Six steps from a blank project to a running autonomous loop.

---

## Step 1 — Bootstrap

In your project directory (must be a git repo):

```bash
git clone https://github.com/lucagattoni/Claude-Warp.git /tmp/claude-warp
bash /tmp/claude-warp/install.sh
```

`install.sh` copies the installer skill and runs `claude -p "/claude-warp-setup"`,
which configures everything autonomously.

**What gets created:**
- `.claude/skills/` — all ClaudeWarp skills installed
- `CLAUDE.md` — filled with your project name and type
- `harness-manifest.json` — version + component registry
- `plans/`, `docs/`, `scripts/` directories
- `logs/` added to `.gitignore`
- A single commit: `chore: install ClaudeWarp loop harness`

---

## Step 2 — Verify the install

```bash
cat harness-manifest.json
```

Check that `project.name` and `project.type` are filled in (not placeholders).
If anything looks wrong, edit `CLAUDE.md` and `harness-manifest.json` directly.

---

## Step 3 — Choose your loop type

ClaudeWarp provides three scaffolding paths depending on goal complexity:

### Simple loop — single agent, one task per run

For daily digests, monitors, audits, and anything that fits in one context window:

```bash
claude -p '/claude-warp-new-loop "check GitHub Issues daily and summarise new ones"'
```

Creates:
- `.claude/skills/<slug>/SKILL.md` — loop logic with guard, state, verify, and stop phases
- `scripts/guard-<slug>.sh` — run-once-per-day / weekday guard
- `scripts/run-<slug>.sh` — headless runner (single agent)
- `<SLUG>_LOG.md` — append-only state file
- `scripts/trigger-<slug>.crontab` — cron snippet to review

Review the generated SKILL.md and expand Phase 3 ("Do the work") for your exact use case.

### Fan-out loop — parallel agents, one per item

For batch jobs where the same task runs against many independent items (files,
issues, PRs, URLs). `new-loop` selects `run-fanout.sh.tpl` automatically when
the goal is batch-shaped:

```bash
claude -p '/claude-warp-new-loop "migrate all Python files in src/ to async/await"'
```

Creates the same files as above, but the runner dispatches one `claude` process per
item in parallel (concurrency capped at `{{MAX_PARALLEL}}`).

### Two-part harness — initializer + coding agent

For large, multi-stage goals that span many context windows and require a planner
to break the work into bounded units before execution:

```bash
claude -p '/claude-warp-new-harness "refactor the auth module to use the new token provider"'
```

Creates:
- `.claude/agents/<slug>-initializer.md` — planner agent that produces a JSON task list
- `<slug>-features.json` — bounded task queue (`pending` → `in_progress` → `done`)
- `<slug>-session-init.md` — read by the coding agent at the start of every context window
- `VISION.md`, `AGENTS.md`, `PROMPT.md` — anchor files (goal / roles / current task)
- `scripts/run-<slug>.sh` — runner: calls initializer once, then loops coding agent until done

To re-task the harness without changing its rules: edit `PROMPT.md` and commit.

---

## Step 4 — Add specialized subagents (optional)

For loops that need independent reviewers, security auditors, or domain specialists:

```bash
claude -p '/claude-warp-new-agent "security reviewer: audits diffs for injection flaws and auth issues"'
```

Creates `.claude/agents/<name>.md` with persona, model, and tool constraints.
Reference it from a skill step: `"Use a subagent to review the diff…"`

---

## Step 5 — Run headlessly

Test before scheduling:

```bash
bash scripts/run-<slug>.sh
```

Check the log:
```bash
cat logs/<slug>-$(date '+%Y%m%d').log
```

Test the guard (run twice — second should skip):
```bash
bash scripts/guard-<slug>.sh && echo "clear" || echo "already ran"
bash scripts/guard-<slug>.sh && echo "clear" || echo "already ran"
```

---

## Step 6 — Schedule

**crontab (Linux / macOS):**
```bash
crontab -e
# paste the contents of scripts/trigger-<slug>.crontab
```

**launchd (macOS — more reliable than crontab):**

Create `~/Library/LaunchAgents/com.claudewarp.<slug>.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>             <string>com.claudewarp.<slug></string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/path/to/project/scripts/run-<slug>.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>    <integer>9</integer>
    <key>Minute</key>  <integer>0</integer>
  </dict>
  <key>RunAtLoad</key> <false/>
</dict>
</plist>
```

Load it:
```bash
launchctl load ~/Library/LaunchAgents/com.claudewarp.<slug>.plist
```

Timestamps use local system time — confirm your OS timezone with `date` before scheduling.

---

## Keeping the harness current

As Claude Code ships new features, some harness components become redundant. Run:

```bash
claude -p "/claude-warp-sync"
```

This re-reads the Claude Code changelog, marks superseded components in
`harness-manifest.json`, and logs migration notes in `HARNESS_SYNC_LOG.md`.

To also check whether new loop engineering patterns from [ClaudeLoops](https://github.com/lucagattoni/Claude-Loops)
are worth adding to ClaudeWarp:

```bash
claude -p "/claude-warp-update"
```

---

## Making the installer globally available (optional)

After your first install, run this once to make `/claude-warp-setup` available in
all future projects without cloning ClaudeWarp again:

```bash
cp -r .claude/skills/claude-warp-setup ~/.claude/skills/
```

Then in any new project:
```bash
claude -p "/claude-warp-setup"
```
