#!/usr/bin/env bash
# ClaudeWarp installer
# Usage: bash /path/to/Claude-Warp/install.sh [TARGET_DIR]
# Default TARGET_DIR is the current directory.
set -euo pipefail

WARP_ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-$(pwd)}"

if [ ! -d "$TARGET" ]; then
  echo "Error: target directory '$TARGET' does not exist." >&2
  exit 1
fi

if [ ! -d "$TARGET/.git" ]; then
  echo "Error: '$TARGET' is not a git repository. Run 'git init' first." >&2
  exit 1
fi

echo "ClaudeWarp → installing into $TARGET"
echo ""

# 1. Copy installer skill into target so Claude can run /claude-warp-setup
mkdir -p "$TARGET/.claude/skills/claude-warp-setup"
cp "$WARP_ROOT/skills/claude-warp-setup/SKILL.md" \
   "$TARGET/.claude/skills/claude-warp-setup/SKILL.md"

# 2. Copy templates and skills alongside (claude-warp-setup reads them)
mkdir -p "$TARGET/.claudewarp-templates"
cp -r "$WARP_ROOT/templates/." "$TARGET/.claudewarp-templates/"
mkdir -p "$TARGET/.claudewarp-skills"
cp -r "$WARP_ROOT/skills/." "$TARGET/.claudewarp-skills/"

# 3. Run claude-warp-setup autonomously
echo "Running /claude-warp-setup in $TARGET ..."
echo ""
cd "$TARGET"
claude \
  --permission-mode auto \
  --max-turns 20 \
  --allowedTools "Read,Edit,Bash" \
  -p "/claude-warp-setup"

# 4. Clean up staging dirs (claude-warp-setup moves skills to .claude/skills/)
rm -rf "$TARGET/.claudewarp-templates" "$TARGET/.claudewarp-skills"

echo ""
echo "Done. Run 'cat harness-manifest.json' to verify."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Optional: make /claude-warp-setup available globally"
echo "(run this once to bootstrap future projects with no script):"
echo ""
echo "  cp -r .claude/skills/claude-warp-setup ~/.claude/skills/"
echo ""
echo "After that, any new project just needs:"
echo "  claude -p \"/claude-warp-setup\""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
