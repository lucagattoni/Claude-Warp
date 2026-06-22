{
  "harness": "ClaudeWarp",
  "version": "{{HARNESS_VERSION}}",
  "installed_at": "{{INSTALLED_AT}}",
  "project": {
    "name": "{{PROJECT_NAME}}",
    "type": "{{PROJECT_TYPE}}",
    "root": "{{REPO_ROOT}}"
  },
  "claude_code": {
    "version_at_install": "{{CC_VERSION}}",
    "last_sync": null
  },
  "components": [
    {
      "name": "scheduling-guards",
      "description": "run-once-per-day and weekday-only guard scripts",
      "native_since": null,
      "status": "active"
    },
    {
      "name": "external-trigger",
      "description": "crontab/launchd snippet to wake claude when daemon is not running",
      "native_since": null,
      "status": "active"
    },
    {
      "name": "cross-run-state",
      "description": "structured tracking files and dedup-across-runs logic",
      "native_since": null,
      "status": "active"
    },
    {
      "name": "changelog-monitor",
      "description": "harness-sync skill that prunes components superseded by Claude Code",
      "native_since": null,
      "status": "active"
    },
    {
      "name": "loop-scaffolder",
      "description": "new-loop skill: goal -> SKILL.md + guard + trigger + state stub",
      "native_since": null,
      "status": "active"
    }
  ],
  "loops": []
}
