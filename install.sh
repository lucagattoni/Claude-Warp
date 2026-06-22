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

# 1. Copy installer skill into target so Claude can run /setup-loop-harness
mkdir -p "$TARGET/.claude/skills/setup-loop-harness"
cp "$WARP_ROOT/skills/setup-loop-harness/SKILL.md" \
   "$TARGET/.claude/skills/setup-loop-harness/SKILL.md"

# 2. Copy templates alongside (setup-loop-harness reads them)
mkdir -p "$TARGET/.claudewarp-templates"
cp -r "$WARP_ROOT/templates/." "$TARGET/.claudewarp-templates/"
cp -r "$WARP_ROOT/skills/." "$TARGET/.claudewarp-skills/"

# 3. Run setup-loop-harness autonomously
echo "Running /setup-loop-harness in $TARGET ..."
echo ""
cd "$TARGET"
claude \
  --permission-mode auto \
  --max-turns 20 \
  --allowedTools "Read,Edit,Bash" \
  -p "/setup-loop-harness"

# 4. Clean up staging dirs (setup-loop-harness moves skills to .claude/skills/)
rm -rf "$TARGET/.claudewarp-templates" "$TARGET/.claudewarp-skills"

echo ""
echo "Done. Run 'cat harness-manifest.json' to verify."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Optional: make /setup-loop-harness available globally"
echo "(run this once to bootstrap future projects with no script):"
echo ""
echo "  cp -r .claude/skills/setup-loop-harness ~/.claude/skills/"
echo ""
echo "After that, any new project just needs:"
echo "  claude -p \"/setup-loop-harness\""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
