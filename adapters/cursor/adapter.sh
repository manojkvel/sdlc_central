#!/bin/bash
# ------------------------------------------------------------------
# Cursor Adapter
# ------------------------------------------------------------------
# Generates .cursor/rules/*.mdc from universal skill format
# (skill.yaml + prompt.md) for Cursor compatibility.
#
# Usage:
#   bash adapter.sh <sdlc-root> <project-dir> <skill-name> [skill-name...]
# ------------------------------------------------------------------

ADAPTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDLC_ROOT="${1:?Usage: adapter.sh <sdlc-root> <project-dir> <skill> [skill...]}"
PROJECT_DIR="${2:?Usage: adapter.sh <sdlc-root> <project-dir> <skill> [skill...]}"
shift 2
SKILLS=("$@")

# Source shared transforms
source "$SDLC_ROOT/adapters/_shared/transform.sh"

# Parse a simple YAML value from a file
yaml_value() {
  local file="$1" key="$2"
  local val
  val=$(grep "^${key}:" "$file" 2>/dev/null | head -1 | sed "s/^${key}:[ ]*//" || true)
  case "$val" in
    \"*\") val="${val#\"}"; val="${val%\"}" ;;
    \'*\') val="${val#\'}"; val="${val%\'}" ;;
  esac
  echo "$val"
}

mkdir -p "$PROJECT_DIR/.cursor/rules"

for skill in "${SKILLS[@]}"; do
  SKILL_YAML="$SDLC_ROOT/skills/$skill/skill.yaml"
  PROMPT_MD="$SDLC_ROOT/skills/$skill/prompt.md"

  if [ ! -f "$SKILL_YAML" ] || [ ! -f "$PROMPT_MD" ]; then
    echo "  ✗ $skill (universal format not found)"
    continue
  fi

  # Read metadata
  DESC=$(yaml_value "$SKILL_YAML" "description")
  ARG_HINT=$(yaml_value "$SKILL_YAML" "argument_hint")

  # Build .mdc file
  {
    echo "---"
    echo "description: \"$DESC\""
    echo "alwaysApply: false"
    echo "---"
    echo ""
    if [ -n "$ARG_HINT" ]; then
      echo "> **Usage:** $ARG_HINT"
      echo ""
    fi
    transform_prompt "cursor" < "$PROMPT_MD"
  } > "$PROJECT_DIR/.cursor/rules/sdlc-${skill}.mdc"

  echo "  ✓ $skill → .cursor/rules/sdlc-${skill}.mdc"
done

# Generate pipeline runner rule (always-on)
PIPELINE_RUNNER="$SDLC_ROOT/pipelines/_engine/PIPELINE-RUNNER.md"
if [ -f "$PIPELINE_RUNNER" ]; then
  {
    echo "---"
    echo "description: \"SDLC Central pipeline runner — execute multi-step workflows\""
    echo "alwaysApply: true"
    echo "---"
    echo ""
    cat "$PIPELINE_RUNNER"
  } > "$PROJECT_DIR/.cursor/rules/sdlc-pipeline-runner.mdc"
  echo "  ✓ pipeline-runner → .cursor/rules/sdlc-pipeline-runner.mdc"
fi

# Generate progress template rule
PROGRESS_TEMPLATE="$SDLC_ROOT/pipelines/_engine/PROGRESS-TEMPLATE.md"
if [ -f "$PROGRESS_TEMPLATE" ]; then
  {
    echo "---"
    echo "description: \"SDLC Central progress file template — persistent memory for pipeline execution\""
    echo "alwaysApply: false"
    echo "---"
    echo ""
    cat "$PROGRESS_TEMPLATE"
  } > "$PROJECT_DIR/.cursor/rules/sdlc-progress-template.mdc"
  echo "  ✓ progress-template → .cursor/rules/sdlc-progress-template.mdc"
fi
