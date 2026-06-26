{
  "harness": "ClaudeWarp",
  "version": "{{HARNESS_VERSION}}",
  "installed_at": "{{INSTALLED_AT}}",
  "last_update": null,
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
      "name": "skill-distribution-workaround",
      "description": "manual skill copying workaround (pre-v2.1.157 compatibility)",
      "native_since": "2.1.157",
      "status": "active",
      "note": "Skills in .claude/skills/ now auto-load natively. This component is kept as a claude-warp-sync self-test: it should be marked superseded on first /claude-warp-sync run."
    },
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
      "status": "active",
      "note": "Cloud alternative: Claude Code Routines (/schedule) run on Anthropic infrastructure with no local machine required. crontab/launchd remain the right choice for local or self-hosted setups."
    },
    {
      "name": "cross-run-state",
      "description": "structured tracking files and dedup-across-runs logic",
      "native_since": null,
      "status": "active"
    },
    {
      "name": "changelog-monitor",
      "description": "claude-warp-sync skill that prunes components superseded by Claude Code",
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
  "loops": [],
  "harnesses": [],
  "agents": []
}
