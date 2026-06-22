# ClaudeWarp — Setup Guide

Six steps from a blank project to a running autonomous loop.

---

## Step 1 — Bootstrap

In your project directory (must be a git repo):

```bash
git clone https://github.com/lucagattoni/Claude-Warp.git /tmp/claude-warp
bash /tmp/claude-warp/install.sh
```

That's it. `install.sh` copies the installer skill and runs
`claude -p "/setup-loop-harness"` which configures everything else autonomously.

**What gets created:**
- `.claude/skills/new-loop/` and `.claude/skills/harness-sync/`
- `CLAUDE.md` (filled with your project name and type)
- `harness-manifest.json` (version + component registry)
- `plans/`, `docs/` directories
- `logs/` added to `.gitignore`
- A single commit: `chore: install ClaudeWarp loop harness`

---

## Step 2 — Verify the install

```bash
cat harness-manifest.json
```

Check that `project.name` and `project.type` are filled in correctly (not placeholders).
If anything looks wrong, edit `CLAUDE.md` and `harness-manifest.json` directly.

To check all required files are present:
```bash
ls .claude/skills/new-loop/SKILL.md \
   .claude/skills/harness-sync/SKILL.md \
   harness-manifest.json \
   CLAUDE.md \
   plans/
```

---

## Step 3 — Scaffold your first loop

Describe your goal in one sentence:

```
claude -p '/new-loop "check GitHub Issues daily and summarise new ones"'
```

Or interactively:
```bash
claude
# then type: /new-loop "check GitHub Issues daily and summarise new ones"
```

`/new-loop` creates:
- `.claude/skills/<slug>/SKILL.md` — the loop logic
- `scripts/guard-<slug>.sh` — prevents duplicate runs
- `scripts/run-<slug>.sh` — headless runner
- `<SLUG>_LOG.md` — append-only state
- `scripts/trigger-<slug>.crontab` — cron snippet to review

Review the generated `SKILL.md` and adjust Phase 3 ("Do the work") for your exact use case.

---

## Step 4 — Run it headlessly

Test the runner before scheduling it:

```bash
bash scripts/run-<slug>.sh
```

Check the log:
```bash
cat logs/<slug>-$(TZ='Europe/Dublin' date '+%Y%m%d').log
```

Test the guard (run twice — second should skip):
```bash
bash scripts/guard-<slug>.sh && echo "clear" || echo "already ran"
bash scripts/guard-<slug>.sh && echo "clear" || echo "already ran"
```

---

## Step 5 — Schedule it

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

**Note on timezones:** cron/launchd use local system time. If your system is set to UTC,
adjust the hour. Irish time is UTC+1 (summer) / UTC+0 (winter).

---

## Step 6 — Iterate: verify → fix → re-run

After your loop runs, check its output:
```bash
cat <SLUG>_LOG.md
```

If the loop output needs improvement, edit `.claude/skills/<slug>/SKILL.md` — specifically
Phase 3. The guard prevents double-runs on the same day; to force a re-run during testing:
```bash
# temporarily bypass the guard:
claude -p "/<slug>"
```

To check whether your harness is still current with the latest Claude Code:
```bash
claude -p "/harness-sync"
```
This re-reads the Claude Code changelog and logs any components that have become native.

---

## Making the installer globally available (optional)

After your first install, run this once to make `/setup-loop-harness` available in all
future projects without needing to clone ClaudeWarp again:

```bash
cp -r .claude/skills/setup-loop-harness ~/.claude/skills/
```

Then in any new project:
```bash
claude -p "/setup-loop-harness"
```
