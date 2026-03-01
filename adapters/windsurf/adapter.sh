#!/bin/bash
# ------------------------------------------------------------------
# Windsurf Adapter
# ------------------------------------------------------------------
# Generates .windsurf/rules/*.md from universal skill format.
# Uses progressive condensation to fit within 6000 character limit
# while preserving valid markdown structure.
# Full versions always stored at .sdlc/skills/<skill>.md.
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

MAX_CHARS=6000
FOOTER_RESERVE=80  # space for the condensation notice

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

# Progressive condensation: strip content in passes until under limit.
# Each pass removes less-critical content while keeping valid markdown.
condense() {
  local content="$1"
  local limit=$((MAX_CHARS - FOOTER_RESERVE))
  local skill_name="$2"

  # Pass 0: Strip YAML frontmatter (--- ... ---) if present at start
  if echo "$content" | head -1 | grep -q '^---$'; then
    content=$(echo "$content" | awk 'NR==1 && /^---$/{skip=1; next} skip && /^---$/{skip=0; next} skip{next} {print}')
  fi

  # Pass 1: Strip fenced code blocks (``` ... ```)
  content=$(echo "$content" | sed '/^```/,/^```/d')
  if [ "$(echo "$content" | wc -c | tr -d ' ')" -le "$limit" ]; then
    echo "$content"; return
  fi

  # Pass 2: Strip markdown tables (lines starting with |)
  content=$(echo "$content" | grep -v '^|')
  if [ "$(echo "$content" | wc -c | tr -d ' ')" -le "$limit" ]; then
    echo "$content"; return
  fi

  # Pass 3: Strip indented code blocks (4+ space indent)
  content=$(echo "$content" | grep -v '^    ')
  if [ "$(echo "$content" | wc -c | tr -d ' ')" -le "$limit" ]; then
    echo "$content"; return
  fi

  # Pass 4: Strip blockquotes (lines starting with >), except first description line
  local first_line
  first_line=$(echo "$content" | head -1)
  content=$(echo "$content" | awk 'NR<=3 {print; next} /^>/ {next} {print}')
  if [ "$(echo "$content" | wc -c | tr -d ' ')" -le "$limit" ]; then
    echo "$content"; return
  fi

  # Pass 5: Keep only headings + numbered list items + bold bullet items
  content=$(echo "$content" | grep -E '^#|^[0-9]+\.|^\*\*|^- \*\*|^$' | head -n 200)
  if [ "$(echo "$content" | wc -c | tr -d ' ')" -le "$limit" ]; then
    echo "$content"; return
  fi

  # Pass 6 (last resort): Headings + first line under each heading
  content=$(echo "$content" | awk '
    /^#/ { print; getline; if (NF > 0) print; next }
    /^$/ { print }
  ' | head -n 150)

  # Final safety: hard truncate at line boundary if still over
  local result=""
  local count=0
  while IFS= read -r line; do
    local new_count=$((count + ${#line} + 1))
    if [ "$new_count" -gt "$limit" ]; then
      break
    fi
    result="$result$line
"
    count=$new_count
  done <<< "$content"
  echo "$result"
}

mkdir -p "$PROJECT_DIR/.windsurf/rules"
mkdir -p "$PROJECT_DIR/.sdlc/skills"

for skill in "${SKILLS[@]}"; do
  SKILL_YAML="$SDLC_ROOT/skills/$skill/skill.yaml"
  PROMPT_MD="$SDLC_ROOT/skills/$skill/prompt.md"

  if [ ! -f "$SKILL_YAML" ] || [ ! -f "$PROMPT_MD" ]; then
    echo "  ✗ $skill (universal format not found)"
    continue
  fi

  DESC=$(yaml_value "$SKILL_YAML" "description")

  # Always store full version (with transforms applied)
  transform_prompt "windsurf" < "$PROMPT_MD" > "$PROJECT_DIR/.sdlc/skills/${skill}.md"

  # Build rule content
  CONTENT="# $skill

> $DESC

$(transform_prompt "windsurf" < "$PROMPT_MD")"

  # Check character limit
  CHAR_COUNT=$(echo "$CONTENT" | wc -c | tr -d ' ')
  if [ "$CHAR_COUNT" -le "$MAX_CHARS" ]; then
    # Fits — write directly
    echo "$CONTENT" > "$PROJECT_DIR/.windsurf/rules/sdlc-${skill}.md"
  else
    # Over limit — progressively condense
    CONDENSED=$(condense "$CONTENT" "$skill")
    {
      echo "$CONDENSED"
      echo ""
      echo "---"
      echo "> Condensed for Windsurf. Full instructions: .sdlc/skills/${skill}.md"
    } > "$PROJECT_DIR/.windsurf/rules/sdlc-${skill}.md"
  fi
  echo "  ✓ $skill → .windsurf/rules/sdlc-${skill}.md"
done

# Generate progress template rule (same condensation logic)
PROGRESS_TEMPLATE="$SDLC_ROOT/pipelines/_engine/PROGRESS-TEMPLATE.md"
if [ -f "$PROGRESS_TEMPLATE" ]; then
  cp "$PROGRESS_TEMPLATE" "$PROJECT_DIR/.sdlc/skills/progress-template.md"

  PT_CONTENT="$(cat "$PROGRESS_TEMPLATE")"
  PT_CHAR_COUNT=$(echo "$PT_CONTENT" | wc -c | tr -d ' ')
  if [ "$PT_CHAR_COUNT" -le "$MAX_CHARS" ]; then
    echo "$PT_CONTENT" > "$PROJECT_DIR/.windsurf/rules/sdlc-progress-template.md"
  else
    PT_CONDENSED=$(condense "$PT_CONTENT" "progress-template")
    {
      echo "$PT_CONDENSED"
      echo ""
      echo "---"
      echo "> Condensed for Windsurf. Full instructions: .sdlc/skills/progress-template.md"
    } > "$PROJECT_DIR/.windsurf/rules/sdlc-progress-template.md"
  fi
  echo "  ✓ progress-template → .windsurf/rules/sdlc-progress-template.md"
fi

# Generate pipeline runner rule (same condensation logic)
PIPELINE_RUNNER="$SDLC_ROOT/pipelines/_engine/PIPELINE-RUNNER.md"
if [ -f "$PIPELINE_RUNNER" ]; then
  RUNNER_CONTENT="$(cat "$PIPELINE_RUNNER")"

  # Store full version
  cp "$PIPELINE_RUNNER" "$PROJECT_DIR/.sdlc/skills/pipeline-runner.md"

  CHAR_COUNT=$(echo "$RUNNER_CONTENT" | wc -c | tr -d ' ')
  if [ "$CHAR_COUNT" -le "$MAX_CHARS" ]; then
    echo "$RUNNER_CONTENT" > "$PROJECT_DIR/.windsurf/rules/sdlc-pipeline-runner.md"
  else
    CONDENSED=$(condense "$RUNNER_CONTENT" "pipeline-runner")
    # Trim leading blank lines from condensed output
    CONDENSED=$(echo "$CONDENSED" | sed '/./,$!d')
    {
      printf '%s\n' "$CONDENSED"
      echo ""
      echo "---"
      echo "> Condensed for Windsurf. Full instructions: .sdlc/skills/pipeline-runner.md"
    } > "$PROJECT_DIR/.windsurf/rules/sdlc-pipeline-runner.md"
  fi
  echo "  ✓ pipeline-runner → .windsurf/rules/sdlc-pipeline-runner.md"
fi
