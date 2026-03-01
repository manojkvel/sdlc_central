#!/bin/bash
# ------------------------------------------------------------------
# Cline Adapter
# ------------------------------------------------------------------
# Generates .clinerules/*.md from universal skill format.
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

mkdir -p "$PROJECT_DIR/.clinerules"

for skill in "${SKILLS[@]}"; do
  SKILL_YAML="$SDLC_ROOT/skills/$skill/skill.yaml"
  PROMPT_MD="$SDLC_ROOT/skills/$skill/prompt.md"

  if [ ! -f "$SKILL_YAML" ] || [ ! -f "$PROMPT_MD" ]; then
    echo "  ✗ $skill (universal format not found)"
    continue
  fi

  DESC=$(yaml_value "$SKILL_YAML" "description")
  CATEGORY=$(yaml_value "$SKILL_YAML" "category")

  # Build Cline rule file with optional YAML conditions
  {
    echo "---"
    echo "description: \"$DESC\""
    echo "category: $CATEGORY"
    echo "---"
    echo ""
    transform_prompt "cline" < "$PROMPT_MD"
  } > "$PROJECT_DIR/.clinerules/sdlc-${skill}.md"

  echo "  ✓ $skill → .clinerules/sdlc-${skill}.md"
done

# Generate pipeline runner rule
PIPELINE_RUNNER="$SDLC_ROOT/pipelines/_engine/PIPELINE-RUNNER.md"
if [ -f "$PIPELINE_RUNNER" ]; then
  {
    echo "---"
    echo "description: \"SDLC Central pipeline runner — execute multi-step workflows\""
    echo "category: pipeline-automation"
    echo "---"
    echo ""
    cat "$PIPELINE_RUNNER"
  } > "$PROJECT_DIR/.clinerules/sdlc-pipeline-runner.md"
  echo "  ✓ pipeline-runner → .clinerules/sdlc-pipeline-runner.md"
fi

# Generate progress template rule
PROGRESS_TEMPLATE="$SDLC_ROOT/pipelines/_engine/PROGRESS-TEMPLATE.md"
if [ -f "$PROGRESS_TEMPLATE" ]; then
  {
    echo "---"
    echo "description: \"SDLC Central progress file template — persistent memory for pipeline execution\""
    echo "category: pipeline-automation"
    echo "---"
    echo ""
    cat "$PROGRESS_TEMPLATE"
  } > "$PROJECT_DIR/.clinerules/sdlc-progress-template.md"
  echo "  ✓ progress-template → .clinerules/sdlc-progress-template.md"
fi
