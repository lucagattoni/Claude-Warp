# Cron trigger for loop: {{SKILL_NAME}}
# Runs at {{CRON_SCHEDULE}} Irish time (IST = UTC+1 summer, UTC+0 winter).
#
# To install: run `crontab -e` and paste the line below.
# Verify with: crontab -l
#
# Note: cron uses UTC. Adjust the hour when DST changes (late Mar / late Oct).
# Summer (IST = UTC+1): subtract 1 from your target IST hour for the UTC value.
# Winter (GMT = UTC+0): use the IST hour directly.
#
# Example: 09:00 IST summer = 08:00 UTC → minute=0, hour=8
#
{{CRON_SCHEDULE}} {{REPO_ROOT}}/scripts/run-{{SKILL_SLUG}}.sh >> {{REPO_ROOT}}/logs/cron-{{SKILL_SLUG}}.log 2>&1

# --- launchd alternative (macOS) ---
# Create ~/Library/LaunchAgents/com.claudewarp.{{SKILL_SLUG}}.plist
# ClaudeWarp can generate this for you: /new-loop will print the plist snippet.
