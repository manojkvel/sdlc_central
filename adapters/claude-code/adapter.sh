#!/bin/bash
# ------------------------------------------------------------------
# Claude Code Adapter
# ------------------------------------------------------------------
# Generates .claude/skills/*/SKILL.md from universal skill format
# (skill.yaml + prompt.md) for Claude Code compatibility.
#
# Usage:
#   bash adapter.sh <sdlc-root> <project-dir> <skill-name> [skill-name...]
# ------------------------------------------------------------------

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDLC_ROOT="${1:?Usage: adapter.sh <sdlc-root> <project-dir> <skill> [skill...]}"
PROJECT_DIR="${2:?Usage: adapter.sh <sdlc-root> <project-dir> <skill> [skill...]}"
shift 2
SKILLS=("$@")

TOOL_MAPPINGS="$ADAPTER_DIR/tool-mappings.yaml"

# Source shared transforms
source "$SDLC_ROOT/adapters/_shared/transform.sh"

# Parse a simple YAML value from a file (macOS-compatible)
# Only strips one layer of outer quotes (either " or ')
yaml_value() {
  local file="$1" key="$2"
  local val
  val=$(grep "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}:[ ]*//" || true)
  # Strip outer double quotes only
  case "$val" in
    \"*\") val="${val#\"}"; val="${val%\"}" ;;
    \'*\') val="${val#\'}"; val="${val%\'}" ;;
  esac
  echo "$val"
}

# Get allowed-tools for a skill from tool-mappings.yaml
get_allowed_tools() {
  local skill="$1" category="$2"

  # Check per-skill overrides first
  local override
  override=$(grep "^  ${skill}:" "$TOOL_MAPPINGS" 2>/dev/null | head -1 | sed "s/^  ${skill}:[ ]*//" | sed 's/^"//;s/"$//' || true)
  if [ -n "$override" ]; then
    echo "$override"
    return
  fi

  # Fall back to category mapping
  local cat_tools
  cat_tools=$(awk "/^  ${category}:/{found=1; next} found && /tools:/{print; exit}" "$TOOL_MAPPINGS" 2>/dev/null | sed 's/.*tools:[ ]*//' | sed 's/^"//;s/"$//')
  if [ -n "$cat_tools" ]; then
    echo "$cat_tools"
    return
  fi

  # Fall back to default
  grep "^default:" "$TOOL_MAPPINGS" | sed 's/^default:[ ]*//' | sed 's/^"//;s/"$//'
}

for skill in "${SKILLS[@]}"; do
  SKILL_YAML="$SDLC_ROOT/skills/$skill/skill.yaml"
  PROMPT_MD="$SDLC_ROOT/skills/$skill/prompt.md"

  if [ ! -f "$SKILL_YAML" ] || [ ! -f "$PROMPT_MD" ]; then
    # Fall back to existing SKILL.md if universal format not available
    if [ -f "$SDLC_ROOT/skills/$skill/SKILL.md" ]; then
      mkdir -p "$PROJECT_DIR/.claude/skills/$skill"
      cp "$SDLC_ROOT/skills/$skill/SKILL.md" "$PROJECT_DIR/.claude/skills/$skill/SKILL.md"
      echo "  ✓ $skill (legacy SKILL.md)"
    else
      echo "  ✗ $skill (not found)"
    fi
    continue
  fi

  # Read metadata from skill.yaml
  NAME=$(yaml_value "$SKILL_YAML" "name")
  DESC=$(yaml_value "$SKILL_YAML" "description")
  ARG_HINT=$(yaml_value "$SKILL_YAML" "argument_hint")
  CATEGORY=$(yaml_value "$SKILL_YAML" "category")

  # Get allowed-tools
  ALLOWED_TOOLS=$(get_allowed_tools "$skill" "$CATEGORY")

  # Build SKILL.md with YAML frontmatter
  mkdir -p "$PROJECT_DIR/.claude/skills/$skill"
  {
    echo "---"
    echo "name: $NAME"
    echo "description: $DESC"
    if [ -n "$ARG_HINT" ]; then
      echo "argument-hint: \"$ARG_HINT\""
    fi
    echo "allowed-tools: $ALLOWED_TOOLS"
    echo "---"
    # Transform agent-agnostic prompt to Claude Code syntax
    transform_prompt "claude-code" < "$PROMPT_MD"
  } > "$PROJECT_DIR/.claude/skills/$skill/SKILL.md"

  echo "  ✓ $skill"
done

# Install pipeline engine
if [ -f "$SDLC_ROOT/pipelines/_engine/PIPELINE-RUNNER.md" ]; then
  mkdir -p "$PROJECT_DIR/.claude/pipelines/_engine"
  cp "$SDLC_ROOT/pipelines/_engine/PIPELINE-RUNNER.md" "$PROJECT_DIR/.claude/pipelines/_engine/PIPELINE-RUNNER.md"
fi

# Install progress template
if [ -f "$SDLC_ROOT/pipelines/_engine/PROGRESS-TEMPLATE.md" ]; then
  mkdir -p "$PROJECT_DIR/.claude/pipelines/_engine"
  cp "$SDLC_ROOT/pipelines/_engine/PROGRESS-TEMPLATE.md" "$PROJECT_DIR/.claude/pipelines/_engine/PROGRESS-TEMPLATE.md"
fi
