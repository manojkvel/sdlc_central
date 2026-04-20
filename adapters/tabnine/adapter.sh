#!/bin/bash
# ------------------------------------------------------------------
# Tabnine CLI Adapter
# ------------------------------------------------------------------
# Generates TABNINE.md + per-skill .md files from universal skill
# format for Tabnine CLI compatibility.
#
# Tabnine CLI reads TABNINE.md hierarchically. Per-skill detail lives
# in .sdlc/skills/ and is pulled in on demand via Tabnine's @path
# syntax or include-dirs configuration.
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

mkdir -p "$PROJECT_DIR/.sdlc/skills"

# Generate per-skill markdown files
for skill in "${SKILLS[@]}"; do
  SKILL_YAML="$SDLC_ROOT/skills/$skill/skill.yaml"
  PROMPT_MD="$SDLC_ROOT/skills/$skill/prompt.md"

  if [ ! -f "$SKILL_YAML" ] || [ ! -f "$PROMPT_MD" ]; then
    echo "  ✗ $skill (universal format not found)"
    continue
  fi

  transform_prompt "tabnine" < "$PROMPT_MD" > "$PROJECT_DIR/.sdlc/skills/${skill}.md"
  echo "  ✓ $skill → .sdlc/skills/${skill}.md"
done

# Install progress template
PROGRESS_TEMPLATE="$SDLC_ROOT/pipelines/_engine/PROGRESS-TEMPLATE.md"
if [ -f "$PROGRESS_TEMPLATE" ]; then
  cp "$PROGRESS_TEMPLATE" "$PROJECT_DIR/.sdlc/skills/progress-template.md"
  echo "  ✓ progress-template → .sdlc/skills/progress-template.md"
fi

# Generate TABNINE.md — root context file with skill index + usage
{
  echo "# SDLC Central — Tabnine Context"
  echo ""
  echo "This project uses SDLC Central for structured software development."
  echo "Tabnine CLI reads this file as hierarchical context."
  echo ""
  echo "Per-skill instructions live in \`.sdlc/skills/\`. Reference a skill"
  echo "in your Tabnine session with \`@.sdlc/skills/<skill>.md\` to pull"
  echo "it into the active context, or configure \`.sdlc/skills/\` as an"
  echo "include directory in Tabnine settings for auto-discovery."
  echo ""
  echo "## Available Skills"
  echo ""
  for skill in "${SKILLS[@]}"; do
    SKILL_YAML="$SDLC_ROOT/skills/$skill/skill.yaml"
    if [ -f "$SKILL_YAML" ]; then
      DESC=$(yaml_value "$SKILL_YAML" "description")
      echo "- **$skill** — $DESC (see \`.sdlc/skills/${skill}.md\`)"
    fi
  done
  echo ""
  echo "## Pipeline Execution"
  echo ""
  echo "Pipelines are YAML files in \`.sdlc/pipelines/\` that chain skills together."
  echo "To run a pipeline, read the pipeline YAML and execute each step's skill in"
  echo "order, passing outputs from one step as inputs to the next."
  echo ""
  echo "Progress template for long-running pipelines: \`.sdlc/skills/progress-template.md\`"
  echo ""
  echo "## Quality Gates"
  echo ""
  echo "Some pipeline steps have quality gates that must pass before proceeding."
  echo "Gate configuration is in \`.sdlc/config/gate-config.json\`."
  echo ""
  echo "## Tabnine-Specific Notes"
  echo ""
  echo "- In interactive mode, Tabnine confirms each action — review and approve."
  echo "- In yolo mode, ensure CI-level gates are in place as a backstop."
  echo "- Enterprise Context Engine (if enabled) overlaps with the \`codebase-qa\`"
  echo "  skill — choose one source of codebase context per query to avoid drift."
} > "$PROJECT_DIR/TABNINE.md"
echo "  ✓ TABNINE.md"
