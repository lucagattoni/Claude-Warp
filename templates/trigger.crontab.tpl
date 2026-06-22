# Cron trigger for loop: {{SKILL_NAME}}
# Runs at {{CRON_SCHEDULE}} local system time.
#
# To install: run `crontab -e` and paste the line below.
# Verify with: crontab -l
#
# Note: cron uses the OS clock — whatever timezone your system is set to.
# Confirm with: date (shows current system time and timezone)
#
{{CRON_SCHEDULE}} {{REPO_ROOT}}/scripts/run-{{SKILL_SLUG}}.sh >> {{REPO_ROOT}}/logs/cron-{{SKILL_SLUG}}.log 2>&1

# --- launchd alternative (macOS) ---
# Create ~/Library/LaunchAgents/com.claudewarp.{{SKILL_SLUG}}.plist
# ClaudeWarp can generate this for you: /claude-warp-new-loop will print the plist snippet.
