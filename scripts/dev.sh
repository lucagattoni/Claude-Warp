#!/usr/bin/env bash
# ClaudeWarp developer tool — self-host skills and verify source integrity.
#
# Usage:
#   scripts/dev.sh selfhost        Symlink skills into .claude/skills/ (single source of truth).
#                                  Makes /claude-warp-* live commands in this repo NEXT session.
#   scripts/dev.sh unhost          Remove the self-host symlinks.
#   scripts/dev.sh verify          Deterministic checks: source integrity + the install copy
#                                  contract + setup/manifest placeholder fill. No tokens, no LLM.
#   scripts/dev.sh verify --live   Also run the REAL /claude-warp-setup (claude -p) into a
#                                  throwaway repo for full fidelity. Costs tokens; needs auth.
#
# What `verify` does and does NOT cover (be honest):
#   - Covers: every skill is well-formed; the documented copy loop lands all skills; the two
#     setup-filled templates (CLAUDE.md, harness-manifest.json) leave no unfilled placeholder;
#     the shared executables (verifier-lib.sh, ledger.sh) pass their own --self-test; the plugin
#     manifest version (.claude-plugin/plugin.json) tracks VERSION.
#   - Does NOT cover: the actual LLM behaviour of /claude-warp-setup. That is non-deterministic
#     and only exercised by `verify --live`.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# ── selfhost ────────────────────────────────────────────────────────────────
selfhost() {
  mkdir -p .claude/skills
  local n=0
  for dir in skills/*/; do
    name="$(basename "$dir")"
    ln -sfn "../../skills/$name" ".claude/skills/$name"   # relative: .claude/skills/<n> → skills/<n>
    n=$((n + 1))
  done
  # Prune symlinks whose source skill no longer exists (e.g. a deleted skill) so a
  # restart never loads a dangling/phantom skill.
  local pruned=0
  for link in .claude/skills/*; do
    [ -L "$link" ] || continue
    sname="$(basename "$link")"
    if [ ! -d "skills/$sname" ]; then rm "$link"; pruned=$((pruned + 1)); fi
  done
  echo "Self-hosted $n skills as symlinks in .claude/skills/ (source of truth stays skills/)."
  [ "$pruned" -gt 0 ] && echo "Pruned $pruned dangling symlink(s) for deleted skills."
  echo "They become live /claude-warp-* commands in your NEXT session in this repo."
}

unhost() {
  local n=0
  if [ -d .claude/skills ]; then
    for link in .claude/skills/*; do
      [ -L "$link" ] && { rm "$link"; n=$((n + 1)); }
    done
  fi
  echo "Removed $n self-host symlinks from .claude/skills/."
}

# ── verify (deterministic) ──────────────────────────────────────────────────
FAIL=0
note_fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
note_ok()   { echo "  ✓ $1"; }

check_source_integrity() {
  echo "[1/12] Source integrity — every skill is well-formed"
  for dir in skills/*/; do
    name="$(basename "$dir")"
    local f="$dir/SKILL.md"
    if [ ! -f "$f" ]; then note_fail "$name: missing SKILL.md"; continue; fi
    grep -q '^name:' "$f"        || note_fail "$name: SKILL.md has no 'name:' frontmatter"
    grep -q '^description:' "$f" || note_fail "$name: SKILL.md has no 'description:' frontmatter"
    local declared; declared="$(grep -m1 '^name:' "$f" | sed 's/^name:[[:space:]]*//')"
    [ "$declared" = "$name" ] || note_fail "$name: frontmatter name '$declared' != directory name"
  done
  [ "$FAIL" -eq 0 ] && note_ok "$(ls -d skills/*/ | wc -l | tr -d ' ') skills well-formed"
}

check_setup_dynamic() {
  echo "[2/12] Regression guard — setup installs skills dynamically (not a hardcoded list)"
  local f="skills/claude-warp-setup/SKILL.md"
  if grep -q 'for dir in "\$WARP_ROOT"/skills/\*/' "$f"; then
    note_ok "setup uses a dynamic copy loop over skills/*/"
  else
    note_fail "setup no longer uses the dynamic skills/*/ loop — it may have regressed to a hardcoded list (see v0.11.1)"
  fi
}

check_copy_contract() {
  echo "[3/12] Copy contract — the documented loop lands every skill"
  local tmp; tmp="$(mktemp -d)"
  local src_count; src_count="$(ls -d skills/*/ | wc -l | tr -d ' ')"
  # Replicate setup Phase 3's documented loop exactly:
  for dir in skills/*/; do
    name="$(basename "$dir")"
    mkdir -p "$tmp/.claude/skills/$name"
    cp "$dir/SKILL.md" "$tmp/.claude/skills/$name/SKILL.md"
  done
  local got; got="$(ls -d "$tmp"/.claude/skills/*/ 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$got" = "$src_count" ]; then
    note_ok "all $got skills copied"
  else
    note_fail "copy landed $got of $src_count skills"
  fi
  for f in "$tmp"/.claude/skills/*/SKILL.md; do
    [ -s "$f" ] || note_fail "empty after copy: $f"
  done
  rm -rf "$tmp"
}

check_placeholder_fill() {
  echo "[4/12] Setup-filled templates leave no unfilled placeholder"
  # Only the two templates /claude-warp-setup fills. Loop/guard/run templates are filled
  # later by /claude-warp-new-loop and are SUPPOSED to still contain {{...}} here.
  local claude_filled manifest_filled
  claude_filled="$(sed \
    -e 's/{{PROJECT_NAME}}/Test/g' -e 's/{{PROJECT_TYPE}}/generic/g' \
    -e 's#{{REPO_ROOT}}#/tmp/x#g' -e 's/{{HARNESS_VERSION}}/0.0.0/g' \
    templates/CLAUDE.md.tpl)"
  if printf '%s' "$claude_filled" | grep -q '{{'; then
    note_fail "CLAUDE.md.tpl has unknown placeholder(s): $(printf '%s' "$claude_filled" | grep -o '{{[^}]*}}' | sort -u | tr '\n' ' ')"
  else
    note_ok "CLAUDE.md.tpl fully fillable"
  fi
  manifest_filled="$(sed \
    -e 's/{{HARNESS_VERSION}}/0.0.0/g' -e 's/{{INSTALLED_AT}}/2026-01-01/g' \
    -e 's/{{PROJECT_NAME}}/Test/g' -e 's/{{PROJECT_TYPE}}/generic/g' \
    -e 's#{{REPO_ROOT}}#/tmp/x#g' -e 's/{{CC_VERSION}}/0.0.0/g' \
    templates/harness-manifest.json.tpl)"
  if printf '%s' "$manifest_filled" | grep -q '{{'; then
    note_fail "harness-manifest.json.tpl has unknown placeholder(s): $(printf '%s' "$manifest_filled" | grep -o '{{[^}]*}}' | sort -u | tr '\n' ' ')"
  elif ! printf '%s' "$manifest_filled" | python3 -m json.tool >/dev/null 2>&1; then
    note_fail "harness-manifest.json.tpl is not valid JSON once filled"
  else
    note_ok "harness-manifest.json.tpl fully fillable and valid JSON"
  fi
}

check_docs_coherence() {
  echo "[5/12] Docs coherence — every skill has a section in reference/skills.md + a README row"
  for dir in skills/*/; do
    name="$(basename "$dir")"
    grep -q "### \`/$name" docs/reference/skills.md || note_fail "$name: no section in docs/reference/skills.md"
    grep -q "/$name" README.md                      || note_fail "$name: not listed in README.md"
  done
  [ "$FAIL" -eq 0 ] && note_ok "all skills documented in reference/skills.md and README"
}

check_executable_selftests() {
  echo "[6/12] Shared executables self-test — verifier-lib + ledger + reviewer-guard fail closed"
  # The shared executables carry their own --self-test. Gate their health here so a regression is
  # caught by CI, not only when a per-PR verifier happens to source one of them.
  if [ -f scripts/verifier-lib.sh ]; then
    bash scripts/verifier-lib.sh --self-test >/dev/null 2>&1 \
      && note_ok "verifier-lib.sh --self-test passes" \
      || note_fail "verifier-lib.sh --self-test FAILED (the shared matcher regressed)"
  else
    note_ok "verifier-lib.sh absent — skipped"
  fi
  if [ -f scripts/ledger.sh ]; then
    bash scripts/ledger.sh --self-test >/dev/null 2>&1 \
      && note_ok "ledger.sh --self-test passes" \
      || note_fail "ledger.sh --self-test FAILED (the ledger regressed)"
  else
    note_ok "ledger.sh absent — skipped"
  fi
  if [ -f scripts/reviewer-guard.sh ]; then
    bash scripts/reviewer-guard.sh --self-test >/dev/null 2>&1 \
      && note_ok "reviewer-guard.sh --self-test passes" \
      || note_fail "reviewer-guard.sh --self-test FAILED (the read-only integrity guard regressed)"
  else
    note_ok "reviewer-guard.sh absent — skipped"
  fi
}

check_claim_count_coherence() {
  echo "[7/12] Behavioural-claim count coherence — the M/N verified-live count is single-sourced"
  local bc=BEHAVIOURAL-CLAIMS.md
  if [ ! -f "$bc" ]; then note_ok "BEHAVIOURAL-CLAIMS.md absent — skipped"; return; fi
  # Compute the count from the registry itself (claim headings), then assert the prose matches it
  # in BOTH the backlog and the docs — so a count update can't half-land (retro: corroboration-rigor).
  local total verified expected
  total="$(grep -cE '^### [0-9]+\. ' "$bc")"
  verified="$(grep -cE '^### [0-9]+\..*verified-live' "$bc")"
  expected="${verified}/${total}"
  grep -qF "$expected" "$bc" \
    || note_fail "BEHAVIOURAL-CLAIMS.md states no '$expected' (computed: $verified verified-live of $total claims)"
  if [ -f docs/reference/architecture.md ]; then
    grep -qF "$expected" docs/reference/architecture.md \
      || note_fail "docs/reference/architecture.md count drifted from the registry's '$expected'"
  fi
  [ "$FAIL" -eq 0 ] && note_ok "backlog count coherent: $expected verified-live (registry == prose in both files)"
}

check_plugin_version_coherence() {
  echo "[8/12] Plugin manifest version coherence — plugin.json tracks VERSION"
  local pj=.claude-plugin/plugin.json
  # Self-host safe: a source repo without a plugin manifest or VERSION has nothing to reconcile.
  if [ ! -f "$pj" ] || [ ! -f VERSION ]; then
    note_ok "no plugin.json / VERSION — skipped (not a packaged plugin)"
    return
  fi
  # The release gate (/claude-warp-release) is read-only and never edits plugin.json, so its
  # "version" can silently lag VERSION (it drifted 0.16.0 vs 0.34.0 before v0.34.1). Pin them here.
  local want got
  want="$(tr -d ' \t\n\r' < VERSION)"
  got="$(python3 -c 'import json; print(json.load(open(".claude-plugin/plugin.json")).get("version",""))' 2>/dev/null)"
  if [ -z "$got" ]; then
    note_fail "plugin.json has no readable \"version\" field"
  elif [ "$got" != "$want" ]; then
    note_fail "plugin.json version '$got' != VERSION '$want' (bump plugin.json on release)"
  else
    note_ok "plugin.json version matches VERSION ($want)"
  fi
}

verify_live() {
  echo
  echo "[live] Real /claude-warp-setup into a throwaway repo (costs tokens)…"
  command -v claude >/dev/null || { echo "  ✗ 'claude' not on PATH"; return 1; }
  local tmp; tmp="$(mktemp -d)"
  ( cd "$tmp" && git init -q && git commit -q --allow-empty -m init )
  bash "$REPO_ROOT/install.sh" "$tmp" || { echo "  ✗ install.sh failed"; rm -rf "$tmp"; return 1; }
  local src_count got
  src_count="$(ls -d skills/*/ | wc -l | tr -d ' ')"
  got="$(ls -d "$tmp"/.claude/skills/*/ 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$got" = "$src_count" ]; then note_ok "live install landed all $got skills"; else note_fail "live install landed $got of $src_count"; fi
  [ -f "$tmp/CLAUDE.md" ] && ! grep -q '{{' "$tmp/CLAUDE.md" && note_ok "CLAUDE.md filled" || note_fail "CLAUDE.md missing or has placeholders"
  [ -f "$tmp/harness-manifest.json" ] && python3 -m json.tool "$tmp/harness-manifest.json" >/dev/null 2>&1 && note_ok "harness-manifest.json valid" || note_fail "harness-manifest.json missing or invalid"
  rm -rf "$tmp"
}

check_scheduled_env_preflight() {
  echo "[9/12] Scheduled-run environment — runners resolve their binaries, cron template sets PATH"
  # cron and launchd run with a minimal PATH that omits ~/.local/bin (where `claude` lives), and
  # stock macOS has no `timeout` at all. Both were silent 127s that only appear when the scaffold
  # is exercised the way a scheduler runs it — so they are gated here, not left to prose.
  for t in run-headless run-two-stage run-fanout; do
    local f="templates/$t.sh.tpl"
    [ -f "$f" ] || { note_fail "$t: template missing"; continue; }
    # Word-anchored: a bare substring grep also matches a mutated `claudeXX`, which is the
    # naive-grep false negative scripts/verifier-lib.sh exists to prevent (caught by mutating
    # this very check — the first version of it passed a template with the preflight removed).
    grep -qE 'command -v claude([^A-Za-z0-9_-]|$)' "$f" \
      || note_fail "$t: no \`claude\` preflight — a cron/launchd run would die with 127"
    grep -qE 'CLAUDE_BIN([^A-Za-z0-9_]|$)' "$f" \
      || note_fail "$t: no CLAUDE_BIN override for a non-standard install path"
  done
  for t in run-headless run-two-stage; do
    local f="templates/$t.sh.tpl"
    [ -f "$f" ] || continue
    grep -qE 'gtimeout([^A-Za-z0-9_-]|$)' "$f" \
      || note_fail "$t: wraps calls in \`timeout\` without a gtimeout fallback (absent on stock macOS)"
    grep -qE 'timeout "\$\{MAX_MINUTES\}m" claude' "$f" \
      && note_fail "$t: still calls \`timeout\` directly instead of the resolved TIMEOUT_CMD"
  done
  grep -q '^PATH=' templates/trigger.crontab.tpl \
    || note_fail "trigger.crontab.tpl sets no PATH — cron cannot find \`claude\`"
  # A JSON read that falls back to a number meaning "no work" reports a green run that did
  # nothing — measured in the harness runner before v0.42.3. Counts must abort, not default.
  local hs="skills/claude-warp-new-harness/SKILL.md"
  if [ -f "$hs" ]; then
    grep -qE 'jnum\(\)[[:space:]]*\{' "$hs" \
      || note_fail "new-harness: no fail-closed jnum() — a failed task-count read can mean 'complete'"
    grep -qE "\|\| echo (0|-1)\)" "$hs" \
      && note_fail "new-harness: a python3 count still falls back to a benign number (|| echo 0/-1)"
    grep -qE 'command -v python3([^A-Za-z0-9_-]|$)' "$hs" \
      || note_fail "new-harness: no python3 preflight — a missing parser reads as an empty queue"
    # The harness runner documents itself as a headless cron re-entry point, so it needs the same
    # binary preflight as its three siblings — it shipped without one in v0.42.2 because this loop
    # covered only templates/.
    grep -qE 'command -v claude([^A-Za-z0-9_-]|$)' "$hs" \
      || note_fail "new-harness: no \`claude\` preflight — its own docs call it a cron re-entry point"
    grep -qE 'CLAUDE_BIN([^A-Za-z0-9_]|$)' "$hs" \
      || note_fail "new-harness: no CLAUDE_BIN override"
    grep -qE 'Unknown command' "$hs" \
      || note_fail "new-harness: no guard for an unresolved slash command (the CLI exits 0 on one)"
  fi
  grep -qE 'command -v python3([^A-Za-z0-9_-]|$)' templates/run-fanout.sh.tpl \
    || note_fail "run-fanout: parses JSON with python3 but does not preflight it"
  [ "$FAIL" -eq 0 ] && note_ok "runners preflight claude/timeout/python3; crontab sets PATH; task counts fail closed"
}

check_runner_execution() {
  echo "[10/12] Runner execution — fill a template and RUN it (greps cannot catch a behaviour bug)"
  # Checks 1-9 read source text. Three of their assertions were defeated live by whitespace, quotes
  # and a name prefix while still printing VERIFY PASSED, and two real behaviour bugs (CLAUDE_BIN
  # being outranked by a native install; the fan-out dropping an unterminated last line) were
  # invisible to every one of them. This check fills a runner and executes it against stub binaries.
  local tmp; tmp="$(mktemp -d)"
  local home="$tmp/home" alt="$tmp/alt" repo="$tmp/repo"
  mkdir -p "$home/.local/bin" "$alt" "$repo/scripts" "$repo/logs" "$repo/.claude/skills/probe"
  printf 'x\n' > "$repo/.claude/skills/probe/SKILL.md"
  ( cd "$repo" && git init -q && git -c user.email=v@x -c user.name=v commit -q --allow-empty -m init )
  # Two stubs that announce which binary ran.
  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo NATIVE-RAN;; esac\n' > "$home/.local/bin/claude"
  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo OVERRIDE-RAN;; esac\n' > "$alt/claude"
  chmod +x "$home/.local/bin/claude" "$alt/claude"

  fill_runner() {  # fill_runner <tpl> <dest> <slug>
    sed -e "s|{{SKILL_NAME}}|probe|g" -e "s|{{SKILL_SLUG}}|$3|g" \
        -e "s|{{MAX_TURNS}}|3|g" -e "s|{{MAX_BUDGET_USD}}|1.00|g" -e "s|{{EFFORT}}|high|g" \
        -e "s|{{ALLOWED_TOOLS}}|Read|g" -e "s|{{DISALLOWED_TOOLS}}|Bash(rm -rf *)|g" \
        "$1" > "$2"
  }
  fill_runner templates/run-headless.sh.tpl "$repo/scripts/run-probe.sh" probe

  # (a) CLAUDE_BIN must outrank an existing native install — the v0.42.2 bug.
  local out
  out=$(cd "$repo" && env -i HOME="$home" PATH=/usr/bin:/bin CLAUDE_BIN="$alt/claude" \
        /bin/bash scripts/run-probe.sh --max-minutes 1 >/dev/null 2>&1; cat logs/*.log 2>/dev/null || true)
  case "$out" in
    *OVERRIDE-RAN*) note_ok "CLAUDE_BIN outranks a native install (executed)" ;;
    *NATIVE-RAN*)   note_fail "CLAUDE_BIN is inert: the native install ran instead of the override" ;;
    *)              note_fail "runner produced no recognizable output; cannot confirm which binary ran" ;;
  esac

  # (b) No claude anywhere must be a loud 127, not a silent pass.
  # NOTE: capture the status explicitly — under `set -e` a bare failing subshell aborts this whole
  # script (it did: the check meant to catch broken gates was itself a broken gate, exit 127).
  local rc=0
  rm -f "$home/.local/bin/claude"
  ( cd "$repo" && rm -f logs/*.log 2>/dev/null; env -i HOME="$home" PATH=/usr/bin:/bin \
      /bin/bash scripts/run-probe.sh --max-minutes 1 >/dev/null 2>&1 ) || rc=$?
  [ "$rc" -eq 127 ] && note_ok "missing claude exits 127 (executed)" \
                    || note_fail "missing claude exited $rc, expected 127"

  # (c) An unresolvable slash command exits 0 in the CLI; the runner must NOT read that as success.
  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo "Unknown command: /probe"; exit 0;; esac\n' > "$alt/claude"
  rc=0
  ( cd "$repo" && rm -f logs/*.log 2>/dev/null; env -i HOME="$home" PATH=/usr/bin:/bin CLAUDE_BIN="$alt/claude" \
      /bin/bash scripts/run-probe.sh --max-minutes 1 >/dev/null 2>&1 ) || rc=$?
  [ "$rc" -ne 0 ] && note_ok "'Unknown command' + CLI exit 0 is not reported as success (executed)" \
                  || note_fail "runner reported success on an unresolved slash command"

  # (d) Budget exhaustion must not be retried — it is a cap, like a timeout, and each retry gets a
  # fresh cap. Observed live: a $0.25 loop burned all three attempts to fail identically.
  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo "Error: Exceeded USD budget (0.25)"; exit 1;; esac\n' > "$alt/claude"
  rc=0
  ( cd "$repo" && rm -f logs/*.log 2>/dev/null; env -i HOME="$home" PATH=/usr/bin:/bin CLAUDE_BIN="$alt/claude" \
      /bin/bash scripts/run-probe.sh --max-minutes 1 >/dev/null 2>&1 ) || rc=$?
  local attempts; attempts=$(grep -c 'Starting probe' "$repo"/logs/*.log 2>/dev/null || echo 0)
  if [ "$rc" -eq 6 ] && [ "$attempts" = "1" ]; then
    note_ok "budget exhaustion fails fast without retrying (exit 6, 1 attempt)"
  else
    note_fail "budget exhaustion: expected exit 6 after 1 attempt, got exit $rc after $attempts attempt(s)"
  fi

  # (e) A run that did NOT complete must not consume the day. Observed live: a handoff wrote its
  # dated section and the guard then blocked the retry for the rest of the day.
  local gsh="$repo/scripts/guard-probe.sh"
  sed -e "s|{{SKILL_NAME}}|probe|g" -e "s|{{STATE_FILE}}|PROBE_LOG.md|g" templates/guard.sh.tpl > "$gsh"
  local today; today="$(date '+%Y-%m-%d')"
  local gv gwant grc gfail=0
  for gv in pass:1 skip:1 handoff:0 fail:0 timeout:0; do
    gwant="${gv##*:}"; gv="${gv%%:*}"
    printf '# probe\n\n<!-- state:\nlast_run: %s 10:00 UTC\nlast_verdict: %s\n-->\n\n## %s — %s\n' \
      "$today" "$gv" "$today" "$gv" > "$repo/PROBE_LOG.md"
    grc=0; ( cd "$repo" && bash scripts/guard-probe.sh >/dev/null 2>&1 ) || grc=$?
    [ "$grc" = "$gwant" ] || { note_fail "guard: verdict '$gv' gave exit $grc, expected $gwant"; gfail=1; }
  done
  [ "$gfail" -eq 0 ] && note_ok "guard blocks only a completed day (pass/skip); handoff/fail/timeout may retry"

  # (f) Fan-out must not drop a final line with no trailing newline — the v0.42.0 bug.
  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; agents) echo "[]";; --bg) echo "backgrounded · deadbeef";; stop) :;; esac\n' > "$alt/claude"
  sed -e "s|{{SKILL_NAME}}|probe|g" -e "s|{{SKILL_SLUG}}|fan|g" -e "s|{{MAX_TURNS}}|3|g" \
      -e "s|{{ALLOWED_TOOLS}}|Read|g" -e "s|{{DISALLOWED_TOOLS}}|Bash(rm -rf *)|g" \
      -e "s|{{TASK_LIST_COMMAND}}|printf 'a\\\\nb\\\\nc'|g" -e "s|{{TASK_PROMPT_PREFIX}}|Do|g" \
      templates/run-fanout.sh.tpl > "$repo/scripts/run-fan.sh"
  local fout
  fout=$(cd "$repo" && env -i HOME="$home" PATH=/usr/bin:/bin CLAUDE_BIN="$alt/claude" \
         CLAUDEWARP_FANOUT_POLL=0 /bin/bash scripts/run-fan.sh --max-minutes 1 2>&1 || true)
  # Assert BOTH the count and the launches. Asserting only the count let a mutant that restored the
  # read-loop drop pass: TOTAL said 3 while the loop launched 2 — the same "internally consistent
  # summary over dropped work" this check exists to catch.
  local counted launched
  counted=$(printf '%s' "$fout" | grep -o 'Tasks generated: [0-9]*' | head -1 | grep -o '[0-9]*' || echo 0)
  launched=$(printf '%s' "$fout" | grep -c 'Launching: ' || true)
  if [ "${counted:-0}" = "3" ] && [ "${launched:-0}" = "3" ]; then
    note_ok "fan-out counts AND launches an unterminated final task (3 counted, 3 launched)"
  else
    note_fail "fan-out dropped an unterminated final task: counted=${counted:-0}, launched=${launched:-0}, expected 3/3"
  fi
  rm -rf "$tmp"
}

check_install_completeness() {
  echo "[11/12] Install completeness — every template a scaffolder reads survives an install"
  # checks 3-4 verify that SKILLS land and that the two SETUP-filled templates are fillable. Nothing
  # verified that the templates the SCAFFOLDERS read are present in an installed project — and they
  # were not: install.sh deletes .claudewarp-templates/, so a real install had no templates at all
  # and /claude-warp-new-loop improvised a runner with none of the shipped hardening. The source repo
  # cannot see this because templates/ sits at its own root.
  local tmp; tmp="$(mktemp -d)"
  # Replicate the documented install: stage, run the setup COPY steps, clean up staging.
  mkdir -p "$tmp/.claudewarp-templates" "$tmp/.claudewarp-skills"
  cp -r templates/. "$tmp/.claudewarp-templates/"
  cp -r skills/. "$tmp/.claudewarp-skills/"
  # …the durable template install claude-warp-setup is responsible for:
  mkdir -p "$tmp/.claudewarp/templates"
  cp "$tmp/.claudewarp-templates"/*.tpl "$tmp/.claudewarp/templates/" 2>/dev/null || true
  rm -rf "$tmp/.claudewarp-templates" "$tmp/.claudewarp-skills"   # install.sh's cleanup

  # Every templates/<x>.tpl any skill tells an agent to read must resolve in that install.
  local missing=0 refs
  refs="$(grep -rhoE '`?templates/[A-Za-z0-9_.-]+\.tpl' skills/*/SKILL.md \
          | sed 's/^`//' | sed 's|^templates/||' | sort -u)"
  local t
  for t in $refs; do
    [ -f "$tmp/.claudewarp/templates/$t" ] || { note_fail "install has no $t — a scaffolder that reads it would improvise"; missing=$((missing+1)); }
  done
  local n; n="$(printf '%s\n' "$refs" | grep -c . || true)"
  [ "$missing" -eq 0 ] && note_ok "all $n scaffolder-referenced templates present after a simulated install"

  # Runtime scripts the emitted instructions depend on must survive an install too — same class as
  # the templates. A live harness worker reported `scripts/check-ai-residuals.sh` as "not run" (the
  # honesty rules mandate it and call it blocking at R2+), and /claude-warp-ledger is a thin wrapper
  # over scripts/ledger.sh, so it could never have worked in an install.
  # Anchor to the COPY LOOP, not the script name: the name also appears in the comment above it, so
  # a bare `grep -q "$rs" install.sh` passes with the copy deleted. That is the fourth time in this
  # repo that an assertion matched its own explanatory prose — hence the anchored form.
  local rs
  for rs in check-ai-residuals.sh ledger.sh; do
    grep -qE "^for s in .*${rs//./\\.}" install.sh \
      || note_fail "install.sh has no copy loop installing scripts/$rs, which emitted instructions require"
  done

  # The simulation above is fiction unless SETUP is actually instructed to perform that copy, so
  # assert the instruction itself — a glob copy of every .tpl into .claudewarp/templates/. Asserting
  # only that the string ".claudewarp/templates" appears somewhere is not enough: it appears in the
  # explanatory prose too, so the check passed while the copy step was mutated away.
  grep -qE 'cp .*\$\{?TEMPLATE_ROOT\}?.*/\*\.tpl[[:space:]]+\.claudewarp/templates/' skills/claude-warp-setup/SKILL.md \
    || note_fail "claude-warp-setup has no glob copy of *.tpl into .claudewarp/templates/ (a partial or absent copy is the shipped bug)"
  # And the scaffolders must be told to resolve from there rather than invent. Require the resolution
  # rule's operative sentence, not merely the path string, for the same reason.
  local sk
  for sk in claude-warp-new-loop claude-warp-new-goal claude-warp-new-harness; do
    grep -qE '1\. `\.claudewarp/templates/<name>\.tpl`' "skills/$sk/SKILL.md" \
      || note_fail "$sk has no template-resolution rule pointing at .claudewarp/templates/"
    grep -q 'Do \*\*not\*\* improvise' "skills/$sk/SKILL.md" \
      || note_fail "$sk does not forbid improvising a missing template (improvising drops every runner guard)"
  done
  rm -rf "$tmp"
}

check_scaffolder_contract() {
  echo "[12/12] Scaffolder contract — placeholders are derived, and --contract is honored"
  # A <TOKEN> in an emitted runner that no phase derives is filled by guesswork. RISK shipped that
  # way: it gates the mandatory QA evaluator and the approval gate in three `case` branches, no
  # phase derived it, and a live scaffold guessed R1 — silently leaving both gates off. Nothing
  # else in the repo would have shown that, because the generated script is syntactically perfect.
  local sk f tok derived
  for sk in claude-warp-new-harness; do
    f="skills/$sk/SKILL.md"
    [ -f "$f" ] || continue
    for tok in $(grep -oE '<[A-Z_]+>' "$f" | sort -u | tr -d '<>'); do
      derived=0
      grep -qE "^- \`$tok\`" "$f" && derived=1
      [ "$derived" -eq 1 ] || note_fail "$sk: <$tok> is emitted into the runner but no phase derives it (it will be guessed)"
    done
  done
  # All three scaffolders must honor the handoff /claude-warp-contract documents.
  for sk in claude-warp-new-loop claude-warp-new-goal claude-warp-new-harness; do
    grep -qE '^## Phase 0 — Contract input' "skills/$sk/SKILL.md" \
      || note_fail "$sk has no Phase 0 contract input, but /claude-warp-contract hands it --contract"
  done
  # And the risk derivation must state a fail-closed default, not merely mention risk.
  grep -q 'use `R2`' skills/claude-warp-new-harness/SKILL.md \
    || note_fail "new-harness does not name a fail-closed default tier for an unclear RISK"
  [ "$FAIL" -eq 0 ] && note_ok "every emitted placeholder is derived; all 3 scaffolders honor --contract"
}

verify() {
  echo "ClaudeWarp verify — deterministic source + install-contract checks"
  echo
  check_source_integrity
  check_setup_dynamic
  check_copy_contract
  check_placeholder_fill
  check_docs_coherence
  check_executable_selftests
  check_claim_count_coherence
  check_plugin_version_coherence
  check_scheduled_env_preflight
  check_runner_execution
  check_install_completeness
  check_scaffolder_contract
  if [ "${1:-}" = "--live" ]; then verify_live; fi
  echo
  if [ "$FAIL" -eq 0 ]; then
    echo "VERIFY PASSED ✓"
  else
    echo "VERIFY FAILED ✗  ($FAIL issue(s))"
    exit 1
  fi
}

# ── dispatch ────────────────────────────────────────────────────────────────
case "${1:-}" in
  selfhost) selfhost ;;
  unhost)   unhost ;;
  verify)   shift; verify "${1:-}" ;;
  *) echo "Usage: scripts/dev.sh {selfhost|unhost|verify [--live]}" >&2; exit 2 ;;
esac
