---
name: claude-warp-new-hook
description: Scaffold a Claude Code hook — 10 named patterns: verify-before-stop, destructive-block, audit-log, subagent-chain, security-scan, evidence-gate, review-gate, kill-switch, steer, intent-gate; writes script and wires into .claude/settings.json
---

Scaffold a hook for: `$ARGUMENTS`

If `$ARGUMENTS` is empty, stop and print:
`Usage: /claude-warp-new-hook "describe what the hook should do"`
Examples:
- `"verify-before-stop: block turn end until npm test passes"`
- `"block destructive commands: deny rm -rf and git push --force"`
- `"audit log: record all Bash tool calls to logs/audit.log"`
- `"security scan: check for hardcoded secrets and --no-verify bypasses"`
- `"evidence gate: block state file writes unless a matching Read happened first"`
- `"review gate: block turn end until the review verdict is APPROVE with no open critical/major"`
- `"kill switch: block all tool calls when AGENT_STOP file exists"`
- `"steer: inject STEER.md content as context once, then clear it"`
- `"intent gate: deny writes outside the task's declared file scope"`

Hooks run deterministic shell scripts at defined lifecycle points — they are
not LLM judgments. Use them when a loop needs hard guarantees, not best-effort
behaviour. Phase 3b (Verify) uses LLM reasoning; a Stop hook uses exit codes.

## Phase 1 — Identify hook pattern

Parse `$ARGUMENTS` and determine which named pattern applies:

| Pattern | Hook event | Exit code 2 blocks | Use when |
|---|---|---|---|
| **verify-before-stop** | `Stop` | Turn end until check passes | Loop must not stop until a test/linter passes |
| **destructive-block** | `PreToolUse` | The tool call | Loop must never run certain commands unattended |
| **audit-log** | `PostToolUse` | Never (async) | Need a tamper-evident record of all tool calls |
| **subagent-chain** | `SubagentStop` | Never (async) | Trigger follow-on work when a background agent finishes |
| **security-scan** | `PostToolUse` | Never (async) | Detect hardcoded secrets, `--no-verify` bypasses, broad `rm -rf` |
| **evidence-gate** | `PreToolUse` | Write/Edit to state file if no prior Read | Prevent false-positive completions: agent cannot write results it hasn't read |
| **review-gate** | `Stop` | Turn end until a persisted review verdict is APPROVE with 0 open critical/major | Enforce that an independent review actually passed before the loop can declare done — separates *review* (produces the verdict) from *enforcement* (this hook) |
| **kill-switch** | `PreToolUse` | All tool calls when `AGENT_STOP` file exists | Operator mid-run halt without killing the process |
| **steer** | `UserPromptSubmit` | Never (context injection) | Mid-run redirection: surfaces `STEER.md` once as context, then clears file |
| **intent-gate** | `PreToolUse` | Write/Edit outside the declared scope glob list | Mechanically enforce a task's negative scope (`must_not_change`/`files_in_scope`) instead of relying on agent self-attestation — default-deny, not trust |

Derive:
- `HOOK_PATTERN` — one of the ten above
- `HOOK_SLUG` — kebab-case name (e.g. `verify-npm-test`, `block-destructive`, `audit-bash`)
- `CHECK_CMD` — the shell command to run (verify-before-stop and destructive-block only)
- `LOOP_SLUG` — the loop this hook belongs to (if scoped; blank = project-wide)
- `SCOPE_GLOBS` — the allow-list of path globs the current work may touch (intent-gate only;
  derive from a harness task's `files_in_scope`, or ask the operator for a static list)

## Phase 2 — Write the hook script

Create `hooks/<HOOK_SLUG>.sh`.

### verify-before-stop

```bash
#!/usr/bin/env bash
# Hook: verify-before-stop for <HOOK_SLUG>
# Event: Stop — blocks turn end (exit 2) until <CHECK_CMD> passes.
# asyncRewake: true — Claude re-enters with failure output as context.
set -euo pipefail

OUTPUT=$(<CHECK_CMD> 2>&1) && EXIT=0 || EXIT=$?

if [ "$EXIT" -ne 0 ]; then
  # Exit 2 = blocking signal; Claude re-enters with additionalContext
  cat <<JSON
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "Stop",
    "additionalContext": "Verification failed. Fix the issues and stop again.\n\n${OUTPUT}"
  }
}
JSON
  exit 2
fi

# Exit 0 = allow Claude to stop
exit 0
```

### destructive-block

```bash
#!/usr/bin/env bash
# Hook: destructive-block for <HOOK_SLUG>
# Event: PreToolUse — denies matching Bash commands (exit 2).
# CRITICAL: exit 2 = deny (blocking). exit 1 = non-blocking warn (permits the action).
# Wrap all deny logic in this script so any unhandled error exits 2, not 1.
set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('command',''))" 2>/dev/null || echo "")

# Add patterns to block; use grep -E for regex
if echo "$CMD" | grep -qE '<BLOCK_PATTERN>'; then
  cat <<JSON
{
  "continue": false,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny"
  }
}
JSON
  exit 2
fi

exit 0
```

### audit-log

```bash
#!/usr/bin/env bash
# Hook: audit-log for <HOOK_SLUG>
# Event: PostToolUse — async fire-and-forget; never blocks.
set -euo pipefail

mkdir -p logs
INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null || echo "unknown")
TS=$(date '+%Y-%m-%d %H:%M:%S %Z')

echo "${TS} | ${TOOL} | $(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('tool_input',''))[:200])" 2>/dev/null)" >> logs/audit.log
exit 0
```

### security-scan

```bash
#!/usr/bin/env bash
# Hook: security-scan for <HOOK_SLUG>
# Event: PostToolUse — async; never blocks; logs findings to logs/security-scan.log.
# Detects: hardcoded secrets (API keys, tokens), --no-verify bypasses, broad destructive
# patterns (rm -rf /, DROP TABLE without WHERE, push --force to main).
set -euo pipefail

mkdir -p logs
INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null || echo "unknown")
CONTENT=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d.get('tool_input','')))" 2>/dev/null || echo "")
TS=$(date '+%Y-%m-%d %H:%M:%S %Z')
FOUND=0

# Secret patterns: adjust regex to your project's key formats
if echo "$CONTENT" | grep -qE '(sk-[a-zA-Z0-9]{32,}|ghp_[a-zA-Z0-9]{36}|AKIA[A-Z0-9]{16}|eyJhbGciO[a-zA-Z0-9_-]{20,})'; then
  echo "${TS} | SECURITY | WARN | possible hardcoded secret in ${TOOL} output" >> logs/security-scan.log
  FOUND=1
fi

# Bypass detection
if echo "$CONTENT" | grep -qE '(--no-verify|--force-with-lease|--allow-unrelated-histories|git push.*--force)'; then
  echo "${TS} | SECURITY | WARN | git safety bypass detected in ${TOOL}: $(echo "$CONTENT" | grep -oE '(--no-verify|--force[^ ]*)')" >> logs/security-scan.log
  FOUND=1
fi

# Broad destructive patterns
if echo "$CONTENT" | grep -qE '(rm -rf /[^/]|DROP TABLE [^W]|DELETE FROM [^ ]+ *;)'; then
  echo "${TS} | SECURITY | WARN | potentially unsafe destructive pattern in ${TOOL}" >> logs/security-scan.log
  FOUND=1
fi

if [ "$FOUND" -eq 1 ]; then
  echo "${TS} | SECURITY | review logs/security-scan.log for flagged items" >> logs/security-scan.log
fi

exit 0
```

### evidence-gate

```bash
#!/usr/bin/env bash
# Hook: evidence-gate for <HOOK_SLUG>
# Event: PreToolUse — blocks Write/Edit to <STATE_FILE> unless a Read of that
# file has been recorded in the session transcript. Prevents false-positive
# completions where the agent writes a pass verdict without reading state first.
# CRITICAL: exit 2 = deny. exit 1 = warn only (accidentally permits).
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")
TARGET=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

# Only gate writes to the state file
STATE_FILE="<STATE_FILE>"
if [[ "$TOOL" =~ ^(Write|Edit)$ ]] && [[ "$TARGET" == *"$STATE_FILE"* ]]; then
  # Check session read log (append Read events via audit-log or companion PostToolUse hook)
  if ! grep -q "Read.*$STATE_FILE" logs/session-reads.log 2>/dev/null; then
    cat <<JSON
{
  "continue": false,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny"
  }
}
JSON
    exit 2
  fi
fi

exit 0
```

### review-gate

Enforces that an **independent review actually passed** before the loop can stop. It does not
*perform* the review — it reads a verdict another surface produced (the contract Phase 6 critical
pass, the QA evaluator, `/claude-warp-converge`, or a manual review), so *review* and *enforcement*
stay separated. The verdict is `.claudewarp/review-result.json` (`review-result.v1` schema):

```json
{
  "schema": "review-result.v1",
  "verdict": "APPROVE | REQUEST_CHANGES | decision_needed",
  "findings": [ { "severity": "critical|major|minor|recommendation", "note": "<what>" } ]
}
```

**Fail-closed:** a missing or unparseable verdict blocks (no review == not approved). Only
`critical`/`major` findings gate — `minor`/`recommendation` never block (mirrors the contract's
severity→verdict rider). To pass, produce/refresh an `APPROVE` verdict with zero open critical/major.

```bash
#!/usr/bin/env bash
# Hook: review-gate for <HOOK_SLUG>
# Event: Stop — blocks turn end (exit 2) until .claudewarp/review-result.json is APPROVE
# with zero open critical/major findings. Fail-closed: missing/unparseable verdict blocks.
# asyncRewake: true — Claude re-enters with the blocking reason as context.
set -euo pipefail

VERDICT_FILE=".claudewarp/review-result.json"

block() {
  cat <<JSON
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "Stop",
    "additionalContext": "Review gate blocked stop: $1\nProduce an APPROVE verdict in ${VERDICT_FILE} (re-run the review) before stopping."
  }
}
JSON
  exit 2
}

[ -f "$VERDICT_FILE" ] || block "no review verdict at ${VERDICT_FILE} (run the review first)"

READ=$(python3 - "$VERDICT_FILE" <<'PY' 2>/dev/null || echo "PARSE_ERROR")
import json,sys
d=json.load(open(sys.argv[1]))
verdict=str(d.get("verdict",""))
blocking=sum(1 for f in d.get("findings",[])
             if str(f.get("severity","")).lower() in ("critical","major"))
print(f"{verdict}\t{blocking}")
PY

[ "$READ" = "PARSE_ERROR" ] && block "review verdict at ${VERDICT_FILE} is unparseable"
VERDICT=$(printf '%s' "$READ" | cut -f1)
BLOCKING=$(printf '%s' "$READ" | cut -f2)

[ "$VERDICT" = "APPROVE" ] || block "verdict is '${VERDICT}', not APPROVE"
[ "${BLOCKING:-0}" -gt 0 ] && block "${BLOCKING} open critical/major finding(s) unresolved"
exit 0
```

### kill-switch

```bash
#!/usr/bin/env bash
# Hook: kill-switch
# Event: PreToolUse — blocks ALL tool calls when AGENT_STOP file exists.
# To halt a running loop: touch AGENT_STOP  (remove it to resume: rm AGENT_STOP)
# CRITICAL: exit 2 = deny. exit 1 = warn only (accidentally permits).
set -euo pipefail

if [ -f "AGENT_STOP" ]; then
  REASON=$(cat AGENT_STOP 2>/dev/null | head -1 || echo "operator halt")
  cat <<JSON
{
  "continue": false,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny"
  }
}
JSON
  exit 2
fi

exit 0
```

### steer

```bash
#!/usr/bin/env bash
# Hook: steer
# Event: UserPromptSubmit — if STEER.md exists, prepend its content as additional
# context and delete the file so it only fires once.
set -euo pipefail

if [ -f "STEER.md" ]; then
  CONTENT=$(cat STEER.md)
  rm -f STEER.md
  cat <<JSON
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Operator steering note (read once, then cleared):\n\n${CONTENT}"
  }
}
JSON
fi

exit 0
```

### intent-gate

```bash
#!/usr/bin/env bash
# Hook: intent-gate for <HOOK_SLUG>
# Event: PreToolUse — denies Write/Edit (exit 2) whose target path falls outside
# the declared scope. Default-deny: a path that matches none of the allowed globs
# is blocked, not waved through. Mechanically enforces negative scope
# (must_not_change / files_in_scope) instead of relying on agent self-attestation.
# CRITICAL: exit 2 = deny. exit 1 = warn only (accidentally permits).
set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || echo "")
TARGET=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

# Only gate file-mutating tools; anything else (Read, Bash, ...) is out of scope for this hook
[[ "$TOOL" =~ ^(Write|Edit)$ ]] || exit 0
[ -n "$TARGET" ] || exit 0

# Allowed-scope globs — fill from <SCOPE_GLOBS> (a task's files_in_scope, or a static list)
ALLOW_GLOBS=(<SCOPE_GLOBS>)

for glob in "${ALLOW_GLOBS[@]}"; do
  # shellcheck disable=SC2053  # intentional unquoted glob match
  if [[ "$TARGET" == $glob ]]; then
    exit 0
  fi
done

cat <<JSON
{
  "continue": false,
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny"
  }
}
JSON
exit 2
```

Create the directory and make executable:
```bash
mkdir -p hooks
chmod +x hooks/<HOOK_SLUG>.sh
```

## Phase 3 — Wire into .claude/settings.json

Read `.claude/settings.json`. If it does not exist, create it as `{}`.

Add the hook under `hooks`. Use `async: true` for audit-log, subagent-chain, and
security-scan patterns. Use `asyncRewake: true` only for verify-before-stop.

**verify-before-stop:**
```json
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": "bash hooks/<HOOK_SLUG>.sh",
        "async": false,
        "asyncRewake": true
      }
    ]
  }
}
```

**destructive-block:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "type": "command",
        "command": "bash hooks/<HOOK_SLUG>.sh",
        "if": "Bash",
        "async": false
      }
    ]
  }
}
```

**audit-log:**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "type": "command",
        "command": "bash hooks/<HOOK_SLUG>.sh",
        "async": true
      }
    ]
  }
}
```

**security-scan:**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "type": "command",
        "command": "bash hooks/<HOOK_SLUG>.sh",
        "async": true
      }
    ]
  }
}
```

**evidence-gate / kill-switch / intent-gate:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "type": "command",
        "command": "bash hooks/<HOOK_SLUG>.sh",
        "async": false
      }
    ]
  }
}
```

**review-gate:** (a `Stop` hook, like verify-before-stop — re-enters on block)
```json
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": "bash hooks/<HOOK_SLUG>.sh",
        "async": false,
        "asyncRewake": true
      }
    ]
  }
}
```

**steer:**
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "type": "command",
        "command": "bash hooks/<HOOK_SLUG>.sh",
        "async": false
      }
    ]
  }
}
```

Read the full existing `.claude/settings.json` as JSON, add the new hook entry
to the appropriate event array (creating the array if absent), then write the
whole file back. Never replace an existing hook array — always append to it.

## Phase 4 — Commit

```bash
mkdir -p hooks
git add hooks/<HOOK_SLUG>.sh .claude/settings.json
git commit -m "feat(hook): add <HOOK_SLUG> (<HOOK_PATTERN>)"
```

## Phase 5 — Report

```
Hook scaffolded ✓

  Pattern  : <HOOK_PATTERN>
  Script   : hooks/<HOOK_SLUG>.sh
  Event    : <HOOK_EVENT>
  Wired in : .claude/settings.json

<HOOK_PATTERN-specific note>
  verify-before-stop: Claude will re-enter with test output as context on
    each failure — fix the failures and stop again to pass the gate.
  destructive-block: matched commands will be denied before execution —
    adjust the BLOCK_PATTERN regex in the script as needed.
  audit-log: all tool calls appended to logs/audit.log asynchronously.
  review-gate: the loop cannot stop until .claudewarp/review-result.json is
    APPROVE with 0 open critical/major. Fail-closed — no verdict = blocked. A
    separate review surface (contract critical pass, QA evaluator, converge, or
    a manual pass) must write the verdict; this hook only enforces it.
  intent-gate: a Write/Edit to a path outside SCOPE_GLOBS is denied before it
    runs — default-deny, not an after-the-fact grading check. Update
    SCOPE_GLOBS in the script when the task's declared scope changes.

Safety note: exit code 2 = blocking deny. An unhandled exception that exits 1
accidentally permits the denied action. Wrap deny logic in try/catch or set -e.
```
