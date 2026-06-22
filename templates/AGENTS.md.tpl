# Agents — {{PROJECT_NAME}}

Defines which agent does what in this multi-agent setup.
The coding agent reads this file via the session-init to understand its role.

## Roles

| Agent | File | Responsibility | May write to |
|---|---|---|---|
| Initializer | `.claude/agents/{{HARNESS_SLUG}}-initializer.md` | Break goal into tasks; populate feature list | `{{FEATURES_FILE}}` |
| Worker | _(invoked directly)_ | Execute one task at a time; commit each unit | Files listed in task `files_in_scope` |

## Handoff protocol

1. Initializer runs once → writes task list to `{{FEATURES_FILE}}`
2. Runner script invokes Worker repeatedly until all tasks are `done`
3. Worker reads session-init at the start of every context window
4. Worker commits after each task and stops — never chains tasks within one session

## Constraints

- Worker must not modify `{{FEATURES_FILE}}` structure — only update `status` and `result` fields
- No agent may touch files outside the scope defined in `VISION.md`
- All commits follow: `harness({{HARNESS_SLUG}}): task <id> — <title>`
