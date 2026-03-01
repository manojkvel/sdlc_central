#!/bin/bash
# ------------------------------------------------------------------
# SDLC Central — Update
# ------------------------------------------------------------------
# Updates skills and pipelines while preserving local config.
# Reads tracking file to know what roles and agent are installed.
#
# Usage:
#   bash /path/to/sdlc_central/setup/update.sh
# ------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDLC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$(pwd)"
VERSION="1.0.0"

echo "╔══════════════════════════════════════════════╗"
echo "║     SDLC Central — Update                    ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# Find tracking file
TRACKING=""
if [ -f "$PROJECT_DIR/.claude/sdlc-central.json" ]; then
  TRACKING="$PROJECT_DIR/.claude/sdlc-central.json"
elif [ -f "$PROJECT_DIR/.sdlc/sdlc-central.json" ]; then
  TRACKING="$PROJECT_DIR/.sdlc/sdlc-central.json"
fi

if [ -z "$TRACKING" ]; then
  echo "Error: SDLC Central not installed in this project."
  echo "No tracking file found (.claude/sdlc-central.json or .sdlc/sdlc-central.json)."
  echo ""
  echo "Run 'bash $SCRIPT_DIR/install.sh' to install first."
  exit 1
fi

# Read installed version, roles, and agent
INSTALLED_VERSION=$(grep '"version"' "$TRACKING" | head -1 | sed 's/.*: *"//' | sed 's/".*//')
INSTALLED_ROLES=$(grep '"roles"' "$TRACKING" | sed 's/.*\[//' | sed 's/\].*//' | tr -d '"' | tr ',' ' ')
INSTALLED_AGENT=$(grep '"agent"' "$TRACKING" 2>/dev/null | sed 's/.*: *"//' | sed 's/".*//')

# Default to claude-code if no agent recorded (legacy installations)
if [ -z "$INSTALLED_AGENT" ]; then
  INSTALLED_AGENT="claude-code"
fi

echo "Installed version: $INSTALLED_VERSION"
echo "Installed roles:   $INSTALLED_ROLES"
echo "Agent:             $INSTALLED_AGENT"
echo "Source:            $SDLC_ROOT"
echo ""

# Check if updating to same version
if [ "$INSTALLED_VERSION" = "$VERSION" ]; then
  echo "Already at version $VERSION — updating skill/pipeline files anyway."
fi

# Run the update
if echo "$INSTALLED_ROLES" | grep -q "all"; then
  echo "Updating all skills and pipelines..."
  echo ""
  bash "$SCRIPT_DIR/install-all.sh" --agent "$INSTALLED_AGENT"
else
  for role in $INSTALLED_ROLES; do
    echo "Updating role: $role"
    bash "$SCRIPT_DIR/install-role.sh" "$role" --agent "$INSTALLED_AGENT"
    echo ""
  done
fi

# NEVER overwrite config files
echo ""
echo "Config:"
echo "  ○ gate-config.json (preserved)"
echo "  ○ balance-sheet-config.json (preserved)"

# Update tracking file timestamp
TRACKING_CONTENT=$(cat "$TRACKING")
echo "$TRACKING_CONTENT" | sed "s/\"updated_at\":.*/\"updated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",/" > "$TRACKING"

echo ""
echo "════════════════════════════════════════════════"
echo "  Updated to version $VERSION (agent: $INSTALLED_AGENT)"
echo "════════════════════════════════════════════════"
