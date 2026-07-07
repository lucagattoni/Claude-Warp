# Guide — Scheduling a loop

Once a loop runs cleanly by hand (see [Choosing & running a scaffold](scaffolding.md)), schedule it.
Three tiers, from lightest to most durable: **session-scoped** (`/loop`) while you have a session
open, **cloud-hosted** (Routines) for unattended runs with no machine, **local** (crontab/launchd)
for unattended runs that need your filesystem or sub-hourly intervals.

## Session-scoped (`/loop`) — while a session is open

Claude Code's native [`/loop`](https://code.claude.com/docs/en/scheduled-tasks) re-runs a prompt —
or a skill, e.g. `/loop 30m /<your-loop-slug>` — on a fixed interval, or self-paced when you omit
the interval. A bare `/loop` runs a built-in maintenance prompt, which a project can replace with
its own `.claude/loop.md`.

Use it to *develop and shake down* a scaffolded loop before scheduling it durably, or for polling
that only matters while you're working anyway. Its bounds are the reason the durable tiers below
exist: tasks are session-scoped (they fire only while the session is open or
[backgrounded](https://code.claude.com/docs/en/agent-view)), and recurring tasks expire after
**7 days**. No guard script or cross-run state is involved — the session's own context is the state.

## Cloud-hosted (Routines) — preferred for unattended runs

Claude Code Routines run on Anthropic infrastructure — no local machine, no daemon required. Set up with the built-in `/schedule` command:

```bash
# Interactive setup
claude -p "/schedule"
```

Routines support three trigger types:
- **Scheduled** — cron-style (minimum 1-hour interval)
- **API** — HTTP POST to a webhook endpoint; fires asynchronously
- **GitHub events** — PR creation, release, push to a path

Permission prompts during a Routine run are routed to your main session asynchronously rather than blocking execution.

## Desktop scheduled tasks — local, no session, Desktop app only

If you run [Claude Code Desktop](https://code.claude.com/docs/en/desktop-scheduled-tasks), its
**Routines** page schedules a **local** task that fires without any open session, keeps 1-minute
granularity, runs against your real files, and persists across app restarts (with a catch-up run
for anything missed in the last 7 days). This covers the same "unattended, local filesystem"
need as crontab/launchd below, with a UI instead of an editable script — but only when the
Desktop app (not the bare CLI) is how you run Claude Code.

## Local scheduling (crontab / launchd)

Use this when you're CLI-only/headless (no Desktop app), need sub-hourly intervals, or are self-hosted.

**crontab:**
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

```bash
launchctl load ~/Library/LaunchAgents/com.claudewarp.<slug>.plist
```

Timestamps use local system time. Confirm your OS timezone with `date` before scheduling.

---

**Before you schedule unattended,** decide how much the loop may do without a human — see
[Deployment posture](deployment.md).
