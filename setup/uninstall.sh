#!/bin/bash
# ------------------------------------------------------------------
# SDLC Central — Uninstall
# ------------------------------------------------------------------
# Removes SDLC Central skills, pipelines, and config from a project.
# Does NOT remove CLAUDE.md (user may have customized it).
#
# Usage:
#   bash /path/to/sdlc_central/setup/uninstall.sh
# ------------------------------------------------------------------

set -e

PROJECT_DIR="$(pwd)"
CLAUDE_DIR="$PROJECT_DIR/.claude"

echo "╔══════════════════════════════════════════════╗"
echo "║     SDLC Central — Uninstall                 ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

if [ ! -f "$CLAUDE_DIR/sdlc-central.json" ]; then
  echo "SDLC Central is not installed in this project."
  exit 0
fi

echo "This will remove from $PROJECT_DIR:"
echo "  - .claude/skills/         (all SDLC Central skills)"
echo "  - .claude/pipelines/      (all pipeline definitions)"
echo "  - .claude/config/         (gate and scoring config)"
echo "  - .claude/sdlc-central.json"
echo ""
echo "CLAUDE.md will NOT be removed (you may have customized it)."
echo ""
echo -n "Proceed? [y/N]: "
read -r CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Cancelled."
  exit 0
fi

echo ""

# Remove skills
if [ -d "$CLAUDE_DIR/skills" ]; then
  rm -rf "$CLAUDE_DIR/skills"
  echo "  ✓ Removed .claude/skills/"
fi

# Remove pipelines
if [ -d "$CLAUDE_DIR/pipelines" ]; then
  rm -rf "$CLAUDE_DIR/pipelines"
  echo "  ✓ Removed .claude/pipelines/"
fi

# Remove config
if [ -d "$CLAUDE_DIR/config" ]; then
  rm -rf "$CLAUDE_DIR/config"
  echo "  ✓ Removed .claude/config/"
fi

# Remove tracking file
if [ -f "$CLAUDE_DIR/sdlc-central.json" ]; then
  rm "$CLAUDE_DIR/sdlc-central.json"
  echo "  ✓ Removed .claude/sdlc-central.json"
fi

# Clean up .claude if empty
if [ -d "$CLAUDE_DIR" ] && [ -z "$(ls -A "$CLAUDE_DIR" 2>/dev/null)" ]; then
  rmdir "$CLAUDE_DIR"
  echo "  ✓ Removed empty .claude/"
fi

echo ""
echo "════════════════════════════════════════════════"
echo "  SDLC Central uninstalled."
echo "════════════════════════════════════════════════"
echo ""
echo "CLAUDE.md was preserved. Remove it manually if desired."
