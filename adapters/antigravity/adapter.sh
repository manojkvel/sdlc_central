#!/bin/bash
# ------------------------------------------------------------------
# Antigravity Adapter
# ------------------------------------------------------------------
# Generates .antigravity/rules/*.md from universal skill format.
# Antigravity uses markdown-based rules and workflows per project.
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

mkdir -p "$PROJECT_DIR/.antigravity/rules"

# Generate per-skill rule files
for skill in "${SKILLS[@]}"; do
  SKILL_YAML="$SDLC_ROOT/skills/$skill/skill.yaml"
  PROMPT_MD="$SDLC_ROOT/skills/$skill/prompt.md"

  if [ ! -f "$SKILL_YAML" ] || [ ! -f "$PROMPT_MD" ]; then
    echo "  ✗ $skill (universal format not found)"
    continue
  fi

  DESC=$(yaml_value "$SKILL_YAML" "description")
  CATEGORY=$(yaml_value "$SKILL_YAML" "category")
  ARG_HINT=$(yaml_value "$SKILL_YAML" "argument_hint")

  # Build rule file
  {
    echo "# $skill"
    echo ""
    echo "> **Category:** $CATEGORY"
    echo "> **Description:** $DESC"
    if [ -n "$ARG_HINT" ]; then
      echo "> **Usage:** $ARG_HINT"
    fi
    echo ""
    transform_prompt "antigravity" < "$PROMPT_MD"
  } > "$PROJECT_DIR/.antigravity/rules/sdlc-${skill}.md"

  echo "  ✓ $skill → .antigravity/rules/sdlc-${skill}.md"
done

# Generate pipeline runner as a workflow
PIPELINE_RUNNER="$SDLC_ROOT/pipelines/_engine/PIPELINE-RUNNER.md"
if [ -f "$PIPELINE_RUNNER" ]; then
  mkdir -p "$PROJECT_DIR/.antigravity/workflows"
  {
    echo "# SDLC Central Pipeline Runner"
    echo ""
    echo "This workflow enables execution of multi-step SDLC pipelines."
    echo ""
    cat "$PIPELINE_RUNNER"
  } > "$PROJECT_DIR/.antigravity/workflows/sdlc-pipeline-runner.md"
  echo "  ✓ pipeline-runner → .antigravity/workflows/sdlc-pipeline-runner.md"
fi

# Generate progress template workflow
PROGRESS_TEMPLATE="$SDLC_ROOT/pipelines/_engine/PROGRESS-TEMPLATE.md"
if [ -f "$PROGRESS_TEMPLATE" ]; then
  mkdir -p "$PROJECT_DIR/.antigravity/workflows"
  {
    echo "# SDLC Central Progress Template"
    echo ""
    echo "Defines the format for pipeline progress files — persistent memory for long-running pipelines."
    echo ""
    cat "$PROGRESS_TEMPLATE"
  } > "$PROJECT_DIR/.antigravity/workflows/sdlc-progress-template.md"
  echo "  ✓ progress-template → .antigravity/workflows/sdlc-progress-template.md"
fi

# Generate index file
{
  echo "# SDLC Central — Antigravity Rules"
  echo ""
  echo "## Available Skills"
  echo ""
  for skill in "${SKILLS[@]}"; do
    SKILL_YAML="$SDLC_ROOT/skills/$skill/skill.yaml"
    if [ -f "$SKILL_YAML" ]; then
      DESC=$(yaml_value "$SKILL_YAML" "description")
      echo "- **$skill** — $DESC (see \`rules/sdlc-${skill}.md\`)"
    fi
  done
  echo ""
  echo "## Pipelines"
  echo ""
  echo "Pipeline definitions are YAML files that chain skills together."
  echo "See \`workflows/sdlc-pipeline-runner.md\` for execution instructions."
} > "$PROJECT_DIR/.antigravity/rules/sdlc-index.md"
echo "  ✓ sdlc-index.md"
