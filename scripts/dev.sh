#!/usr/bin/env bash
# ClaudeWarp developer tool — self-host skills and verify source integrity.
#
# Usage:
#   scripts/dev.sh selfhost        Symlink skills into .claude/skills/ (single source of truth).
#                                  Makes /claude-warp-* live commands in this repo NEXT session.
#   scripts/dev.sh unhost          Remove the self-host symlinks.
#   scripts/dev.sh verify          Deterministic checks: source integrity + the install copy
#                                  contract + setup/manifest placeholder fill. No tokens, no LLM.
#   scripts/dev.sh portability     Fill the runner templates and EXECUTE them against stub binaries,
#                                  asserting observed exit codes. Add --docker to also run the same
#                                  suite inside debian (bash 5.x + real `timeout`, with and without
#                                  python3). No tokens, no auth, no network beyond the image pull.
#   scripts/dev.sh verify --live   Also run the REAL /claude-warp-setup (claude -p) into a
#                                  throwaway repo for full fidelity. Costs tokens; needs auth.
#
# What `verify` does and does NOT cover (be honest):
#   - Covers: every skill is well-formed; the documented copy loop lands all skills; the two
#     setup-filled templates (CLAUDE.md, harness-manifest.json) leave no unfilled placeholder;
#     the shared executables (verifier-lib.sh, ledger.sh) pass their own --self-test; the plugin
#     manifest version (.claude-plugin/plugin.json) tracks VERSION.
#   - Does NOT cover: the actual LLM behaviour of /claude-warp-setup. That is non-deterministic
#     and only exercised by `verify --live`. It also does not cover how a FILLED runner behaves in a
#     different OS — `verify` check 10 executes one on this host only. `scripts/dev.sh portability
#     --docker` is what covers the environment-dependent branches (timeout present vs absent,
#     python3 present vs absent), and it found no defects when first run across macOS and debian.
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
# A check reports its OWN result, not the global tally: check_begin snapshots the counter and
# check_ok prints only if THIS check added nothing to it. Both always return 0 — a check whose
# last statement returned non-zero used to trip `set -e` and kill the run before its own verdict
# banner (measured: one planted failure reached 7 of 13 checks and printed no banner at all).
CHECK_FAIL0=0
check_begin() { CHECK_FAIL0=$FAIL; return 0; }
check_ok()    { [ "$FAIL" -eq "$CHECK_FAIL0" ] && note_ok "$1"; return 0; }

# errexit stays live INSIDE each check body on purpose — a broken `mktemp`/`git init` must be
# fatal rather than silently producing garbage. The cost is that a check which CRASHES ends the
# run before the verdict, reproducing the exact no-banner symptom that per-check returns fixed for
# a check that merely REPORTS a failure. Measured while adding the state-header check: one
# uncaptured `( … )` exiting 1 killed the run after printing only its own header. This trap
# guarantees the gate always says something.
VERDICT_PRINTED=0
verify_crash_guard() {
  [ "$VERDICT_PRINTED" -eq 1 ] && return 0
  echo
  echo "VERIFY CRASHED ✗ — a check aborted before the verdict banner."
  echo "  This is a fault in the CHECK itself, not necessarily in the artifact it inspects."
  echo "  The last '[N/14]' line above names the check that died."
}

check_source_integrity() {
  echo "[1/14] Source integrity — every skill is well-formed"
  check_begin
  for dir in skills/*/; do
    name="$(basename "$dir")"
    local f="$dir/SKILL.md"
    if [ ! -f "$f" ]; then note_fail "$name: missing SKILL.md"; continue; fi
    grep -q '^name:' "$f"        || note_fail "$name: SKILL.md has no 'name:' frontmatter"
    grep -q '^description:' "$f" || note_fail "$name: SKILL.md has no 'description:' frontmatter"
    local declared; declared="$(grep -m1 '^name:' "$f" | sed 's/^name:[[:space:]]*//')"
    [ "$declared" = "$name" ] || note_fail "$name: frontmatter name '$declared' != directory name"
  done
  check_ok "$(ls -d skills/*/ | wc -l | tr -d ' ') skills well-formed"
  return 0
  return 0
}

check_setup_dynamic() {
  echo "[2/14] Regression guard — setup installs skills dynamically (not a hardcoded list)"
  local f="skills/claude-warp-setup/SKILL.md"
  if grep -q 'for dir in "\$WARP_ROOT"/skills/\*/' "$f"; then
    note_ok "setup uses a dynamic copy loop over skills/*/"
  else
    note_fail "setup no longer uses the dynamic skills/*/ loop — it may have regressed to a hardcoded list (see v0.11.1)"
  fi
  return 0
}

check_copy_contract() {
  echo "[3/14] Copy contract — the documented loop lands every skill"
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
  return 0
}

check_placeholder_fill() {
  echo "[4/14] Setup-filled templates leave no unfilled placeholder"
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
  return 0
}

check_docs_coherence() {
  echo "[5/14] Docs coherence — every skill has a section in reference/skills.md + a README row"
  check_begin
  for dir in skills/*/; do
    name="$(basename "$dir")"
    grep -q "### \`/$name" docs/reference/skills.md || note_fail "$name: no section in docs/reference/skills.md"
    grep -q "/$name" README.md                      || note_fail "$name: not listed in README.md"
  done
  check_ok "all skills documented in reference/skills.md and README"
  return 0
}

check_executable_selftests() {
  echo "[6/14] Shared executables self-test — verifier-lib + ledger + reviewer-guard fail closed"
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
  return 0
}

check_claim_count_coherence() {
  echo "[7/14] Behavioural-claim count coherence — the M/N verified-live count is single-sourced"
  check_begin
  local bc=BEHAVIOURAL-CLAIMS.md
  if [ ! -f "$bc" ]; then note_ok "BEHAVIOURAL-CLAIMS.md absent — skipped"; return; fi
  # Compute the count from the registry itself (claim headings), then assert the prose matches it
  # in BOTH the backlog and the docs — so a count update can't half-land (retro: corroboration-rigor).
  local total verified expected
  total="$(grep -cE '^### [0-9]+\. ' "$bc" || true)"
  verified="$(grep -cE '^### [0-9]+\..*verified-live' "$bc" || true)"
  expected="${verified}/${total}"
  grep -qF "$expected" "$bc" \
    || note_fail "BEHAVIOURAL-CLAIMS.md states no '$expected' (computed: $verified verified-live of $total claims)"
  if [ -f docs/reference/architecture.md ]; then
    grep -qF "$expected" docs/reference/architecture.md \
      || note_fail "docs/reference/architecture.md count drifted from the registry's '$expected'"
  fi
  check_ok "backlog count coherent: $expected verified-live (registry == prose in both files)"
  return 0
}

check_plugin_version_coherence() {
  echo "[8/14] Plugin manifest version coherence — plugin.json tracks VERSION"
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
  command -v claude >/dev/null || { note_fail "'claude' not on PATH — the live gate could not run"; return 0; }
  local tmp; tmp="$(mktemp -d)"
  ( cd "$tmp" && git init -q && git commit -q --allow-empty -m init )
  bash "$REPO_ROOT/install.sh" "$tmp" || { note_fail "install.sh failed"; rm -rf "$tmp"; return 0; }
  local src_count got
  src_count="$(ls -d skills/*/ | wc -l | tr -d ' ')"
  got="$(ls -d "$tmp"/.claude/skills/*/ 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$got" = "$src_count" ]; then note_ok "live install landed all $got skills"; else note_fail "live install landed $got of $src_count"; fi
  [ -f "$tmp/CLAUDE.md" ] && ! grep -q '{{' "$tmp/CLAUDE.md" && note_ok "CLAUDE.md filled" || note_fail "CLAUDE.md missing or has placeholders"
  [ -f "$tmp/harness-manifest.json" ] && python3 -m json.tool "$tmp/harness-manifest.json" >/dev/null 2>&1 && note_ok "harness-manifest.json valid" || note_fail "harness-manifest.json missing or invalid"
  rm -rf "$tmp"
  return 0
}

check_scheduled_env_preflight() {
  echo "[9/14] Scheduled-run environment — runners resolve their binaries, cron template sets PATH"
  check_begin
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
  check_ok "runners preflight claude/timeout/python3; crontab sets PATH; task counts fail closed"
  return 0
}

check_runner_execution() {
  echo "[10/14] Runner execution — fill a template and RUN it (greps cannot catch a behaviour bug)"
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

  # (d2) A FATAL exit must still report whether the attempt left work behind. Before this, a run
  # that committed and THEN hit its cap logged a bare failure, losing the one fact that decides
  # whether re-running is safe. The stub commits, then reports budget exhaustion.
  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo landed > landed.txt; git add landed.txt >/dev/null 2>&1; git -c user.email=v@x -c user.name=v commit -q -m "work landed" >/dev/null 2>&1; echo "Error: Exceeded USD budget (0.25)"; exit 1;; esac\n' > "$alt/claude"
  rc=0
  ( cd "$repo" && rm -f logs/*.log 2>/dev/null; env -i HOME="$home" PATH=/usr/bin:/bin CLAUDE_BIN="$alt/claude" \
      /bin/bash scripts/run-probe.sh --max-minutes 1 >/dev/null 2>&1 ) || rc=$?
  attempts=$(grep -c 'Starting probe' "$repo"/logs/*.log 2>/dev/null || echo 0)
  if [ "$rc" -eq 6 ] && [ "$attempts" = "1" ] && grep -q 'DURABLE TRACE' "$repo"/logs/*.log 2>/dev/null; then
    note_ok "budget exhaustion after work landed reports the durable trace (exit 6, 1 attempt)"
  else
    note_fail "budget exhaustion that COMMITTED work: expected exit 6, 1 attempt and a DURABLE TRACE note; got exit $rc, $attempts attempt(s), trace=$(grep -c 'DURABLE TRACE' "$repo"/logs/*.log 2>/dev/null || echo 0)"
  fi

  # (d3) The timeout branch had the same hole, three lines above code that already did this.
  # Anchor on the literal sentence: a bare 'TIMEOUT' also matches CLAUDEWARP_REQUIRE_TIMEOUT in
  # the no-timeout-binary notice, which prints on hosts with neither timeout nor gtimeout.
  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo landed2 > landed2.txt; git add landed2.txt >/dev/null 2>&1; git -c user.email=v@x -c user.name=v commit -q -m "work landed 2" >/dev/null 2>&1; exit 124;; esac\n' > "$alt/claude"
  rc=0
  ( cd "$repo" && rm -f logs/*.log 2>/dev/null; env -i HOME="$home" PATH=/usr/bin:/bin CLAUDE_BIN="$alt/claude" \
      /bin/bash scripts/run-probe.sh --max-minutes 1 >/dev/null 2>&1 ) || rc=$?
  if [ "$rc" -eq 1 ] && grep -q 'TIMEOUT: attempt exceeded' "$repo"/logs/*.log 2>/dev/null \
       && grep -q 'DURABLE TRACE' "$repo"/logs/*.log 2>/dev/null; then
    note_ok "timeout after work landed reports the durable trace (exit 1)"
  else
    note_fail "timeout that COMMITTED work: expected exit 1 with both 'TIMEOUT: attempt exceeded' and a DURABLE TRACE note; got exit $rc"
  fi

  # (d5) A session/usage limit is a wall, not a transient drop. Found live: `claude -p` printed
  # "You've hit your session limit · resets 3:10am" and exited 1 — the generic code this runner
  # retries — so a scheduled loop would burn its whole backoff window failing identically and
  # report a bare failure, losing the reset time. Must exit 7 after exactly one attempt.
  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo "You'"'"'ve hit your session limit \xc2\xb7 resets 3:10am (Europe/Dublin)"; exit 1;; esac\n' > "$alt/claude"
  rc=0
  ( cd "$repo" && rm -f logs/*.log 2>/dev/null; env -i HOME="$home" PATH=/usr/bin:/bin CLAUDE_BIN="$alt/claude" \
      /bin/bash scripts/run-probe.sh --max-minutes 1 >/dev/null 2>&1 ) || rc=$?
  attempts=$(grep -c 'Starting probe' "$repo"/logs/*.log 2>/dev/null || echo 0)
  if [ "$rc" -eq 7 ] && [ "$attempts" = "1" ]; then
    note_ok "session limit is a wall, not a transient: exit 7 after 1 attempt (executed)"
  else
    note_fail "session limit: expected exit 7 after 1 attempt, got exit $rc after $attempts attempt(s) — a limit that reads as a generic transient burns the whole backoff window"
  fi
  # The reset time is the one fact the operator needs; a bare "it failed" loses it. Anchor on the
  # runner's OWN diagnostic line: the stub's raw output is appended to the same log, so a bare
  # `grep 'resets 3:10am'` passes even with the echo deleted (caught by mutating exactly that).
  grep -qE 'FATAL: the account hit its session/usage limit .*resets 3:10am' "$repo"/logs/*.log 2>/dev/null \
    || note_fail "session-limit branch did not carry the CLI's reset time into its own FATAL line"
  # Markers must DISCRIMINATE: the budget stub above exits 6, this one 7. If either matched both,
  # the two branches would be interchangeable and neither assertion would mean anything.
  grep -q 'exhausted its --max-budget-usd cap' "$repo"/logs/*.log 2>/dev/null \
    && note_fail "a session-limit run was reported as budget exhaustion — the two markers do not discriminate"

  # (d6) NEGATIVE POLE for (d5). The marker is two ordinary English phrases, so it must not fire on
  # a run that SUCCEEDED and merely discussed them. Measured before the rc gate: a stub exiting 0
  # while printing "Documented the usage limit handling" was reported FATAL, exit 7 — the guard
  # would have killed a working loop.
  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo "Done. Documented the usage limit handling. 2 files changed."; exit 0;; esac\n' > "$alt/claude"
  rc=0
  ( cd "$repo" && rm -f logs/*.log 2>/dev/null; env -i HOME="$home" PATH=/usr/bin:/bin CLAUDE_BIN="$alt/claude" \
      /bin/bash scripts/run-probe.sh --max-minutes 1 >/dev/null 2>&1 ) || rc=$?
  if [ "$rc" -eq 0 ] && ! grep -q 'hit its session/usage limit' "$repo"/logs/*.log 2>/dev/null; then
    note_ok "a successful run that merely mentions a usage limit is not killed (negative pole)"
  else
    note_fail "(d6) a SUCCESSFUL run mentioning 'usage limit' exited $rc and/or was reported as a session limit — the marker fires on prose, so (d5) proves nothing"
  fi

  # (d4) NEGATIVE POLE — mandatory. The probe repo above leaves .claude/ untracked, so
  # `git status --porcelain` is never empty there and tree_dirty() is unconditionally true: a
  # positive-only assertion cannot tell "durable_trace was consulted" from "the note prints
  # always". This repo is genuinely clean (logs/ gitignored, as claude-warp-setup guarantees),
  # and the stub changes nothing — so the note must be ABSENT.
  local clean="$tmp/clean"
  mkdir -p "$clean/scripts" "$clean/logs" "$clean/.claude/skills/probe"
  printf 'x\n' > "$clean/.claude/skills/probe/SKILL.md"
  printf 'logs/\n' > "$clean/.gitignore"
  fill_runner templates/run-headless.sh.tpl "$clean/scripts/run-probe.sh" probe
  ( cd "$clean" && git init -q && git add -A \
      && git -c user.email=v@x -c user.name=v commit -q -m init )
  local dirty; dirty="$( cd "$clean" && git status --porcelain )"
  if [ -n "$dirty" ]; then
    note_fail "(d4) setup error: the clean probe repo is not clean [$dirty] — the negative pole would be vacuous"
  else
    printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo "Error: Exceeded USD budget (0.25)"; exit 1;; esac\n' > "$alt/claude"
    rc=0
    ( cd "$clean" && env -i HOME="$home" PATH=/usr/bin:/bin CLAUDE_BIN="$alt/claude" \
        /bin/bash scripts/run-probe.sh --max-minutes 1 >/dev/null 2>&1 ) || rc=$?
    if [ "$rc" -eq 6 ] && ! grep -q 'DURABLE TRACE' "$clean"/logs/*.log 2>/dev/null; then
      note_ok "a fatal exit that left NOTHING behind reports no durable trace (negative pole)"
    else
      note_fail "(d4) a run that changed nothing still reported a DURABLE TRACE (exit $rc) — the trace note is unconditional, so (d2)/(d3) prove nothing"
    fi
  fi

  # (w) --worktree mode had NO coverage at all (`grep -c worktree scripts/dev.sh` was 0), yet it is
  # the mode the template header recommends for unattended L3 loops, and durable_trace() behaves
  # differently there: it keys on origin advancing rather than on the local tree. report_trace now
  # runs on that path too, calling snapshot() -> `git fetch origin`. All of it, until now, unrun.
  local ori="$tmp/origin.git" wrepo="$tmp/wrepo"
  git init -q --bare "$ori"
  git clone -q "$ori" "$wrepo" 2>/dev/null
  mkdir -p "$wrepo/scripts" "$wrepo/logs" "$wrepo/.claude/skills/probe"
  printf 'x\n' > "$wrepo/.claude/skills/probe/SKILL.md"
  printf 'logs/\n' > "$wrepo/.gitignore"
  fill_runner templates/run-headless.sh.tpl "$wrepo/scripts/run-probe.sh" probe
  ( cd "$wrepo" && git add -A && git -c user.email=v@x -c user.name=v commit -q -m init \
      && git push -q origin HEAD:main 2>/dev/null && git remote set-head origin main 2>/dev/null )
  # (w1) Happy path: a successful --worktree run exits 0 and LEAVES NOTHING BEHIND. A leaked
  # worktree or branch on every cron fire is the failure mode nobody notices until disk fills.
  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo WT-OK;; esac\n' > "$alt/claude"
  rc=0
  ( cd "$wrepo" && env -i HOME="$home" PATH=/usr/bin:/bin CLAUDE_BIN="$alt/claude" \
      /bin/bash scripts/run-probe.sh --max-minutes 1 --worktree >/dev/null 2>&1 ) || rc=$?
  local leaked_wt leaked_br
  leaked_wt=$( cd "$wrepo" && git worktree list 2>/dev/null | grep -c 'probe-worktree' || true )
  leaked_br=$( cd "$wrepo" && git branch --list 'probe-2*' 2>/dev/null | grep -c . || true )
  if [ "$rc" -eq 0 ] && [ "$leaked_wt" = "0" ] && [ "$leaked_br" = "0" ]; then
    note_ok "--worktree: clean run exits 0 and leaks no worktree or branch (executed)"
  else
    note_fail "--worktree: exit $rc, leaked worktrees=$leaked_wt branches=$leaked_br (a cron loop would accumulate both)"
  fi
  # (w2) The real test of report_trace on this path: the stub PUSHES, then fails. durable_trace
  # keys on origin here, so the trace must be reported — and a bare failure would hide that a
  # push already landed.
  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo pushed > landed.txt; git add landed.txt >/dev/null 2>&1; git -c user.email=v@x -c user.name=v commit -q -m "landed" >/dev/null 2>&1; git push -q origin HEAD:main >/dev/null 2>&1; echo "Error: Exceeded USD budget (0.25)"; exit 1;; esac\n' > "$alt/claude"
  rc=0
  ( cd "$wrepo" && rm -f logs/*.log 2>/dev/null; env -i HOME="$home" PATH=/usr/bin:/bin CLAUDE_BIN="$alt/claude" \
      /bin/bash scripts/run-probe.sh --max-minutes 1 --worktree >/dev/null 2>&1 ) || rc=$?
  if [ "$rc" -eq 6 ] && grep -q 'DURABLE TRACE' "$wrepo"/logs/*.log 2>/dev/null \
       && grep -q 'origin/main advanced' "$wrepo"/logs/*.log 2>/dev/null; then
    note_ok "--worktree: a push that landed before the cap is reported as a durable trace (executed)"
  else
    note_fail "--worktree: expected exit 6 with a DURABLE TRACE naming origin advancement; got exit $rc"
  fi
  # (w3) NEGATIVE POLE: same mode, stub pushes nothing. origin did not move, so no trace.
  printf '#!/bin/bash\ncase "$1" in --help) echo "  --permission-prompts <target>";; *) echo "Error: Exceeded USD budget (0.25)"; exit 1;; esac\n' > "$alt/claude"
  rc=0
  ( cd "$wrepo" && rm -f logs/*.log 2>/dev/null; env -i HOME="$home" PATH=/usr/bin:/bin CLAUDE_BIN="$alt/claude" \
      /bin/bash scripts/run-probe.sh --max-minutes 1 --worktree >/dev/null 2>&1 ) || rc=$?
  if [ "$rc" -eq 6 ] && ! grep -q 'DURABLE TRACE' "$wrepo"/logs/*.log 2>/dev/null; then
    note_ok "--worktree: a run that pushed nothing reports no durable trace (negative pole)"
  else
    note_fail "--worktree (w3): a run that advanced origin by nothing still reported a DURABLE TRACE (exit $rc) — (w2) proves nothing"
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
  return 0
}

check_install_completeness() {
  echo "[11/14] Install completeness — every template a scaffolder reads survives an install"
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

  # Installing an artifact is not enough — setup must COMMIT it, or it exists only for whoever ran
  # install.sh and a teammate's fresh clone gets skills referencing files that are not there.
  # v0.44.0 installed the runtime scripts and forgot to track them; a live inventory run reported
  # `?? scripts/` and a clone of that project had 13 templates and 0 scripts.
  # Reconstruct the actual `git add` command (joining backslash continuations) rather than matching
  # line patterns: the paths sit on a continuation line, and the first version of this assertion
  # failed on the unmutated tree because of exactly that.
  local addcmd tracked
  addcmd="$(awk '/^git add /{c=$0; while (c ~ /\\$/) {sub(/\\$/,"",c); if ((getline nx)<=0) break; c=c nx} print c}' \
            skills/claude-warp-setup/SKILL.md)"
  for tracked in '.claudewarp/templates/' 'scripts/check-ai-residuals.sh' 'scripts/ledger.sh'; do
    case "$addcmd" in
      *"$tracked"*) ;;
      *) note_fail "claude-warp-setup's git add does not track $tracked — it will not survive a clone" ;;
    esac
  done

  # Paths the emitted CLAUDE.md points at must exist in an INSTALL (or be a URL). It referenced
  # `templates/...` and `docs/guides/...`, neither of which an install has.
  local ref
  for ref in $(grep -oE '`(docs|templates)/[a-zA-Z0-9./-]+`' templates/CLAUDE.md.tpl | tr -d '`'); do
    note_fail "CLAUDE.md.tpl points at '$ref', which does not exist in an installed project"
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
  return 0
}

check_scaffolder_contract() {
  echo "[12/14] Scaffolder contract — placeholders are derived, and --contract is honored"
  check_begin
  # The scaffolder's state-file stub must satisfy the two consumers it hands the file to: the
  # generated loop's Phase 2 (which READS six fields) and guard-<slug>.sh (which parses last_run /
  # last_verdict out of it). The shipped stub seeded none of them, so run #1 read a header that was
  # never written and Phase 4 "incremented" counters that did not exist. Extract the stub the
  # scaffolder actually emits and EXECUTE the guard against it — a grep for the field names would
  # equally match the template's own prose describing them.
  local stub; stub="$(python3 - <<'PYX'
import re
s = open('skills/claude-warp-new-loop/SKILL.md').read()
m = re.search(r'\*\*2d\. State file stub\*\*.*?```markdown\n(.*?)```', s, re.S)
print(m.group(1) if m else '', end='')
PYX
)"
  if [ -z "$stub" ]; then
    note_fail "new-loop: could not extract the 2d state-file stub (its fenced markdown block moved or vanished)"
  else
    local fld
    for fld in last_run last_verdict runs_total consecutive_fails consecutive_stagnation acting_on; do
      printf '%s\n' "$stub" | grep -qE "^${fld}:" \
        || note_fail "new-loop stub seeds no '$fld:' — the generated loop's Phase 2 reads it on run #1"
    done
    printf '%s\n' "$stub" | grep -q '<!-- state:' \
      || note_fail "new-loop stub has no '<!-- state:' block — Phase 4 has nothing to update"
    # Behavioural: the seeded stub must leave a freshly scaffolded loop CLEAR TO RUN. An empty
    # last_run would instead drop the guard into its conservative legacy branch.
    local gtmp; gtmp="$(mktemp -d)"
    mkdir -p "$gtmp/scripts"
    printf '%s\n' "$stub" > "$gtmp/PROBE_LOG.md"
    sed -e 's|{{SKILL_NAME}}|Probe|g' -e 's|{{STATE_FILE}}|PROBE_LOG.md|g' \
        templates/guard.sh.tpl > "$gtmp/scripts/guard.sh"
    # errexit is deliberately live inside check bodies, so an expected non-zero must be captured
    # explicitly rather than left to trip it.
    local grc; grc=0; ( cd "$gtmp" && bash scripts/guard.sh >/dev/null 2>&1 ) || grc=$?
    [ "$grc" -eq 0 ] \
      || note_fail "the seeded stub makes guard.sh exit $grc on a never-run loop (expected 0 = clear to run)"
    # Negative pole: the same guard must still CLOSE the day on a completed run, or the assertion
    # above is satisfied by a guard that can only ever say yes.
    sed -e "s|^last_run: never|last_run: $(date '+%Y-%m-%d') 09:00 UTC|" \
        -e 's|^last_verdict: none|last_verdict: pass|' "$gtmp/PROBE_LOG.md" > "$gtmp/PROBE_LOG.md.new"
    mv "$gtmp/PROBE_LOG.md.new" "$gtmp/PROBE_LOG.md"
    grc=0; ( cd "$gtmp" && bash scripts/guard.sh >/dev/null 2>&1 ) || grc=$?
    [ "$grc" -eq 1 ] \
      || note_fail "guard.sh exits $grc after a completed run today (expected 1 = skip); the clear-to-run assertion above is vacuous"
    rm -rf "$gtmp"
  fi
  # Phase 2 must initialise on a MISSING BLOCK, not merely a missing file — the scaffolder always
  # creates the file, so keying on existence skips initialisation for every scaffolded loop.
  grep -q 'exists without a `<!-- state:` block' templates/loop.SKILL.md.tpl \
    || note_fail "loop template's Phase 2 still keys the create-branch on file existence, which the scaffolder guarantees is false"
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
  check_ok "every emitted placeholder is derived; all 3 scaffolders honor --contract"
  return 0
}

check_emitted_gates() {
  echo "[13/14] Emitted gates — hooks read the real payload, and every runner shape is hardened"
  check_begin
  local hk="skills/claude-warp-new-hook/SKILL.md"
  # A PreToolUse payload nests the command at tool_input.command. destructive-block read the
  # top-level `command`, which is always empty, so it blocked NOTHING while looking like a gate —
  # found by dogfooding, and the worst shape possible in the pattern sold as a hard guarantee.
  if [ -f "$hk" ]; then
    grep -qE "d\.get\('command'" "$hk" \
      && note_fail "new-hook: a template reads top-level 'command'; a PreToolUse payload nests it at tool_input.command, so the hook would block nothing"
    grep -qE "tool_input.*command" "$hk" \
      || note_fail "new-hook: destructive-block does not read tool_input.command"
    grep -q 'failing closed' "$hk" \
      || note_fail "new-hook: destructive-block does not fail closed on an empty/unexpected payload"
  fi
  # Every runner shape must carry the same hardening. The goal runner is written inline in its skill
  # rather than filled from templates/, and it silently drifted to 1-of-7 until v0.45.1.
  local gs="skills/claude-warp-new-goal/SKILL.md" pat missing=0
  if [ -f "$gs" ]; then
    # Word-anchored: a plain substring match also accepts a mutated `command -v claudeXX`. That is
    # the same unanchored-grep false negative this repo has now reintroduced eight times; it is
    # never caught by reading the assertion, only by mutating the thing it guards.
    for pat in 'command -v claude' 'CLAUDE_BIN' 'permission-prompts' 'disallowedTools' 'Unknown command' 'Exceeded USD budget'; do
      grep -qE "${pat}([^A-Za-z0-9_-]|\$)" "$gs" || { note_fail "new-goal's runner lacks '$pat' — the loop runners guarantee it; goals must not drift"; missing=$((missing+1)); }
    done
  fi
  check_ok "hook templates read tool_input and fail closed; goal runner at parity with loop runners"
}

verify() {
  echo "ClaudeWarp verify — deterministic source + install-contract checks"
  echo
  VERDICT_PRINTED=0
  trap verify_crash_guard EXIT
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
  check_emitted_gates
  check_skill_contracts
  if [ "${1:-}" = "--live" ]; then verify_live; fi
  echo
  # Disarm only AFTER the banner is on screen. Setting VERDICT_PRINTED before the echo left a
  # window in which a fault printed nothing at all — the exact pre-fix symptom this trap exists to
  # close, and the invariant three lines above claims to hold.
  if [ "$FAIL" -eq 0 ]; then
    echo "VERIFY PASSED ✓"
  else
    echo "VERIFY FAILED ✗  ($FAIL issue(s))"
  fi
  VERDICT_PRINTED=1
  trap - EXIT
  [ "$FAIL" -eq 0 ] || exit 1
}

check_skill_contracts() {
  echo "[14/14] Skill contracts — retro's inputs and vocabulary match the loop it reads"
  check_begin
  local rt="skills/claude-warp-retro/SKILL.md"
  # A retro is only as honest as its verdict vocabulary. `stopped` is a first-class verdict in the
  # loop template; omitting it from FAIL_ENTRIES hides a security/permission gate firing, and
  # omitting it (and `timeout`) from the Runs: line makes stated-total != sum-of-buckets by
  # construction. Verified live against a 12-run fixture: the fixed skill emitted
  # "10 total | 5 pass | 2 fail | 1 handoff | 1 skip | 1 timeout | 0 stopped", which sums to 10.
  grep -qE '^- `FAIL_ENTRIES`.*stopped' "$rt" \
    || note_fail "retro: FAIL_ENTRIES omits 'stopped' — a fired permission gate reads as a clean run"
  local v
  for v in pass fail handoff skip timeout stopped; do
    grep -qE '^\*\*Runs:\*\*.*<'"$v"'>' "$rt" \
      || note_fail "retro: the Runs: line names no <$v> bucket — the stated total cannot equal the sum"
  done
  # The git-history query must be scoped to THIS loop. A pathspec union pulls a sibling loop's
  # commits into the retro, and the loop template explicitly anticipates several loops per repo.
  grep -qE "git log .*'\*_LOG\.md'" "$rt" \
    && note_fail "retro: git log still unions the generic '*_LOG.md' pathspec — a sibling loop's commits enter the retro"
  grep -q 'git log --oneline --since="$SINCE" -- "$STATE_FILE"' "$rt" \
    || note_fail "retro: git log is not scoped to the resolved STATE_FILE"
  # The window must follow the runs, not a constant: a weekly loop's last 10 runs span ~70 days.
  # Only the git query is forbidden from hard-coding the window; "30 days ago" survives as the
  # documented FALLBACK for a state file with no dated sections yet, which is correct.
  grep -qE 'git log .*--since="30 days ago"' "$rt" \
    && note_fail "retro: the git window is still a hard-coded 30 days, which disagrees with the 10-run window Phase 3 reads"
  grep -q 'SINCE="$(grep -oE' "$rt" \
    || note_fail "retro: --since is not derived from the dated sections Phase 3 actually reads"
  # An append-only file read top-down yields the OLDEST ten, the opposite of what Phase 3 wants.
  grep -qE "grep -nE '\^## \[0-9\]\{4\}" "$rt" \
    || note_fail "retro: Phase 3 gives no bounded command for the NEWEST 10 sections (a top-down read returns the oldest)"
  # A guard-fired skip writes neither STATE_FILE nor a commit, so silence must not read as success.
  grep -q 'GUARD_EVIDENCE' "$rt" \
    || note_fail "retro: no GUARD_EVIDENCE input — the guard question is answered from data that cannot contain the answer"

  local up="skills/claude-warp-update/SKILL.md"
  # These assertions must not match the skill's own PROSE explaining why the old forms are wrong —
  # an unanchored grep matching its own explanatory comment is this repo's most-repeated defect.
  # So each anchors on the INSTRUCTION form: a fenced command, or a bullet that assigns a field.
  grep -qE '^\s*(WebFetch|`?WebFetch) https://' "$up" \
    && note_fail "update: still instructs a WebFetch of a raw URL — LLM-mediated content cannot satisfy the byte-diff contract it also requires"
  grep -qE '^- `harness\.(version|last_update)`' "$up" \
    && note_fail "update: still writes harness.version/harness.last_update — 'harness' is the string \"ClaudeWarp\"; that would clobber it with an object"
  grep -q 'curl -fsSL' "$up" \
    || note_fail "update: no curl fetch — Phase 3's byte diff has no byte-exact source"
  # git's multi-pathspec add is atomic: without the guard a manifest-less project stages NOTHING
  # and loses the whole commit after the skills were already rewritten on disk (exit 128).
  grep -qF 'if [ -f harness-manifest.json ]; then git add harness-manifest.json; fi' "$up" \
    || note_fail "update: Phase 6 does not add the manifest conditionally — a project without one loses the entire commit (git add is atomic)"
  grep -qE '^git add \.claude/skills/ harness-manifest\.json' "$up" \
    && note_fail "update: Phase 6 still adds both paths in one atomic git add"
  # A 200 with an empty/truncated body is neither a network error nor an HTTP error, so without
  # this criterion it reads as "differs" and Phase 4 replaces a working skill with nothing.
  grep -q 'the body is empty' "$up" \
    || note_fail "update: fetch-failed does not cover an empty 200 body — a working skill would be overwritten with nothing"
  grep -q 'could not reach GitHub' "$up" \
    || note_fail "update: Phase 2 has no abort branch — a non-array response (403 rate limit, truncation) marks every installed skill an orphan"
  check_ok "retro reads this loop only, over the window it analyses, with all six verdicts; update fetches byte-exact and fails closed"
  return 0
}

# ── dispatch ────────────────────────────────────────────────────────────────
case "${1:-}" in
  selfhost) selfhost ;;
  unhost)   unhost ;;
  verify)   shift; verify "${1:-}" ;;
  portability) shift; exec bash "$REPO_ROOT/tests/portability/run.sh" "${1:-}" ;;
  *) echo "Usage: scripts/dev.sh {selfhost|unhost|verify [--live]|portability [--docker]}" >&2; exit 2 ;;
esac
