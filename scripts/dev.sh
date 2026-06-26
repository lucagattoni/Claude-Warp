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
#     setup-filled templates (CLAUDE.md, harness-manifest.json) leave no unfilled placeholder.
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
  echo "[1/5] Source integrity — every skill is well-formed"
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
  echo "[2/5] Regression guard — setup installs skills dynamically (not a hardcoded list)"
  local f="skills/claude-warp-setup/SKILL.md"
  if grep -q 'for dir in "\$WARP_ROOT"/skills/\*/' "$f"; then
    note_ok "setup uses a dynamic copy loop over skills/*/"
  else
    note_fail "setup no longer uses the dynamic skills/*/ loop — it may have regressed to a hardcoded list (see v0.11.1)"
  fi
}

check_copy_contract() {
  echo "[3/5] Copy contract — the documented loop lands every skill"
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
  echo "[4/5] Setup-filled templates leave no unfilled placeholder"
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
  echo "[5/5] Docs coherence — every skill has a section in loop-harness.md + a README row"
  for dir in skills/*/; do
    name="$(basename "$dir")"
    grep -q "### \`/$name" docs/loop-harness.md || note_fail "$name: no section in docs/loop-harness.md"
    grep -q "/$name" README.md                  || note_fail "$name: not listed in README.md"
  done
  [ "$FAIL" -eq 0 ] && note_ok "all skills documented in loop-harness.md and README"
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

verify() {
  echo "ClaudeWarp verify — deterministic source + install-contract checks"
  echo
  check_source_integrity
  check_setup_dynamic
  check_copy_contract
  check_placeholder_fill
  check_docs_coherence
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
