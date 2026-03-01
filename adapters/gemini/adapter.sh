#!/bin/bash
# ------------------------------------------------------------------
# Gemini Adapter
# ------------------------------------------------------------------
# Generates GEMINI.md at project root from universal skill format.
# Gemini CLI reads GEMINI.md as project-level instructions,
# similar to CLAUDE.md for Claude Code.
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

{
  echo "# SDLC Central — Project Skills"
  echo ""
  echo "This project uses SDLC Central for structured software development."
  echo "Below are the available skills. When asked to perform a task, check"
  echo "if a matching skill exists and follow its phased instructions."
  echo ""
  echo "## Skills Index"
  echo ""

  # Build index
  for skill in "${SKILLS[@]}"; do
    SKILL_YAML="$SDLC_ROOT/skills/$skill/skill.yaml"
    if [ -f "$SKILL_YAML" ]; then
      DESC=$(yaml_value "$SKILL_YAML" "description")
      CATEGORY=$(yaml_value "$SKILL_YAML" "category")
      echo "- **${skill}** (\`${CATEGORY}\`) — $DESC"
    fi
  done

  echo ""
  echo "---"
  echo ""

  # Include full skill content
  for skill in "${SKILLS[@]}"; do
    SKILL_YAML="$SDLC_ROOT/skills/$skill/skill.yaml"
    PROMPT_MD="$SDLC_ROOT/skills/$skill/prompt.md"

    if [ ! -f "$SKILL_YAML" ] || [ ! -f "$PROMPT_MD" ]; then
      continue
    fi

    DESC=$(yaml_value "$SKILL_YAML" "description")
    CATEGORY=$(yaml_value "$SKILL_YAML" "category")
    ARG_HINT=$(yaml_value "$SKILL_YAML" "argument_hint")

    echo "## $skill"
    echo ""
    echo "> **Category:** $CATEGORY | $DESC"
    if [ -n "$ARG_HINT" ]; then
      echo "> **Usage:** $ARG_HINT"
    fi
    echo ""
    transform_prompt "gemini" < "$PROMPT_MD"
    echo ""
    echo "---"
    echo ""
  done

  # Pipeline execution guide
  echo "## Pipeline Execution"
  echo ""
  echo "Pipelines are YAML files that chain skills together in sequence."
  echo "Each pipeline defines steps with dependencies and optional quality gates."
  echo ""
  echo "### How to Run a Pipeline"
  echo ""
  echo "1. Read the pipeline YAML file (e.g., \`pipelines/<role>/<name>.pipeline.yaml\`)"
  echo "2. Execute each step in dependency order, invoking the corresponding skill"
  echo "3. Pass the output of each step as input to dependent steps"
  echo "4. At quality gates, validate output meets thresholds before proceeding"
  echo "5. At HITL (human-in-the-loop) gates, pause and ask the user for approval"
  echo ""

  # Include pipeline runner if available
  PIPELINE_RUNNER="$SDLC_ROOT/pipelines/_engine/PIPELINE-RUNNER.md"
  if [ -f "$PIPELINE_RUNNER" ]; then
    echo "### Pipeline Runner Reference"
    echo ""
    cat "$PIPELINE_RUNNER"
    echo ""
  fi

  # Include progress template if available
  PROGRESS_TEMPLATE="$SDLC_ROOT/pipelines/_engine/PROGRESS-TEMPLATE.md"
  if [ -f "$PROGRESS_TEMPLATE" ]; then
    echo "### Progress File Template"
    echo ""
    cat "$PROGRESS_TEMPLATE"
    echo ""
  fi

} > "$PROJECT_DIR/GEMINI.md"

echo "  ✓ GEMINI.md (${#SKILLS[@]} skills)"
