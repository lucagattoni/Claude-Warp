# Cron trigger for loop: {{SKILL_NAME}}
# Runs at {{CRON_SCHEDULE}} local system time.
#
# To install: run `crontab -e` and paste the block below (PATH line included).
# Verify with: crontab -l
#
# Note: cron uses the OS clock — whatever timezone your system is set to.
# Confirm with: date (shows current system time and timezone)
#
# PATH IS LOAD-BEARING. cron does not read your shell profile: it runs with a minimal
# PATH (often just /usr/bin:/bin) that does NOT include ~/.local/bin, where the native
# installer puts `claude`. Without the line below a scheduled run dies at its first
# `claude` call with exit 127 and the loop never runs. The runner also prepends the usual
# install locations itself and aborts loudly if it still cannot find the binary, so this
# line is belt-and-braces — keep both.
PATH={{HOME}}/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin

{{CRON_SCHEDULE}} {{REPO_ROOT}}/scripts/run-{{SKILL_SLUG}}.sh >> {{REPO_ROOT}}/logs/cron-{{SKILL_SLUG}}.log 2>&1

# Before trusting the schedule, run it the way cron will — with none of your shell's
# environment — and confirm it does not die on a missing binary:
#   env -i HOME="$HOME" PATH=/usr/bin:/bin {{REPO_ROOT}}/scripts/run-{{SKILL_SLUG}}.sh
# Expect the runner's FATAL line if PATH is wrong; expect a normal run if it is right.

# --- launchd alternative (macOS) ---
# Create ~/Library/LaunchAgents/com.claudewarp.{{SKILL_SLUG}}.plist
# launchd has the SAME minimal-PATH problem as cron — set EnvironmentVariables in the
# plist (see the scheduling guide for the full file).
# ClaudeWarp can generate this for you: /claude-warp-new-loop will print the plist snippet.
