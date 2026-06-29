# Guide — Scheduling a loop

Once a loop runs cleanly by hand (see [Choosing & running a scaffold](scaffolding.md)), schedule it
to run unattended. Pick **cloud-hosted** when you can; fall back to **local** scheduling when you need
sub-hourly intervals or local-filesystem access at runtime.

## Cloud-hosted (Routines) — preferred when available

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

## Local scheduling (crontab / launchd)

Use this when you need sub-hourly intervals, access to the local filesystem at runtime, or are self-hosted.

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
