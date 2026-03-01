#!/bin/bash
# ------------------------------------------------------------------
# GitHub Copilot Adapter
# ------------------------------------------------------------------
# Generates .github/instructions/*.instructions.md from universal
# skill format for GitHub Copilot compatibility.
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

# Map skill category to Copilot applyTo glob pattern
category_to_glob() {
  case "$1" in
    development)     echo "**/*.{ts,tsx,js,jsx,py,go,rs,java}" ;;
    planning)        echo "specs/**,docs/**" ;;
    quality)         echo "**/*.{ts,tsx,js,jsx,py,go,rs,java,test.*}" ;;
    governance)      echo "**/*" ;;
    production-support) echo "**/*" ;;
    maintenance)     echo "package.json,requirements.txt,go.mod,Cargo.toml,**/*" ;;
    *)               echo "" ;;
  esac
}

mkdir -p "$PROJECT_DIR/.github/instructions"

# Generate per-skill instruction files
for skill in "${SKILLS[@]}"; do
  SKILL_YAML="$SDLC_ROOT/skills/$skill/skill.yaml"
  PROMPT_MD="$SDLC_ROOT/skills/$skill/prompt.md"

  if [ ! -f "$SKILL_YAML" ] || [ ! -f "$PROMPT_MD" ]; then
    echo "  ✗ $skill (universal format not found)"
    continue
  fi

  # Read metadata
  DESC=$(yaml_value "$SKILL_YAML" "description")
  CATEGORY=$(yaml_value "$SKILL_YAML" "category")
  APPLY_TO=$(category_to_glob "$CATEGORY")

  # Build .instructions.md file
  {
    echo "---"
    if [ -n "$APPLY_TO" ]; then
      echo "applyTo: \"$APPLY_TO\""
    fi
    echo "---"
    echo ""
    echo "# $skill"
    echo ""
    echo "> $DESC"
    echo ""
    transform_prompt "copilot" < "$PROMPT_MD"
  } > "$PROJECT_DIR/.github/instructions/sdlc-${skill}.instructions.md"

  echo "  ✓ $skill → .github/instructions/sdlc-${skill}.instructions.md"
done

# Generate progress template instructions file
PROGRESS_TEMPLATE="$SDLC_ROOT/pipelines/_engine/PROGRESS-TEMPLATE.md"
if [ -f "$PROGRESS_TEMPLATE" ]; then
  {
    echo "---"
    echo "applyTo: \"**/*\""
    echo "---"
    echo ""
    echo "# SDLC Central Progress Template"
    echo ""
    echo "> Defines the format for pipeline progress files — persistent memory for long-running pipelines."
    echo ""
    cat "$PROGRESS_TEMPLATE"
  } > "$PROJECT_DIR/.github/instructions/sdlc-progress-template.instructions.md"
  echo "  ✓ progress-template → .github/instructions/sdlc-progress-template.instructions.md"
fi

# Generate global copilot instructions
{
  echo "# SDLC Central"
  echo ""
  echo "This project uses SDLC Central skills for structured software development."
  echo "See .github/instructions/ for individual skill definitions."
  echo ""
  echo "## Available Skills"
  echo ""
  for skill in "${SKILLS[@]}"; do
    SKILL_YAML="$SDLC_ROOT/skills/$skill/skill.yaml"
    if [ -f "$SKILL_YAML" ]; then
      DESC=$(yaml_value "$SKILL_YAML" "description")
      echo "- **$skill**: $DESC"
    fi
  done
  echo ""
  echo "## Pipelines"
  echo ""
  echo "Pipeline definitions are in the pipelines/ directory as YAML files."
  echo "Each pipeline chains multiple skills together with quality gates."
} > "$PROJECT_DIR/.github/copilot-instructions.md"
echo "  ✓ copilot-instructions.md"
