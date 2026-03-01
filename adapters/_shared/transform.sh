#!/bin/bash
# ------------------------------------------------------------------
# Shared Adapter Transforms
# ------------------------------------------------------------------
# Provides agent-specific transforms for prompt.md content.
# Adapters source this file, then pipe content through transforms.
#
# Usage (from an adapter):
#   source "$SDLC_ROOT/adapters/_shared/transform.sh"
#   CONTENT=$(transform_prompt "$AGENT" < "$PROMPT_MD")
# ------------------------------------------------------------------

# Transform tool invocation syntax from agent-agnostic to agent-specific.
# Agent-agnostic prompt.md uses:
#   Search for files: <pattern>
#   Search for content: <pattern>
# Each agent maps these to its native tool syntax.
transform_tool_syntax() {
  local agent="$1"
  case "$agent" in
    claude-code)
      sed 's/^Search for files: /Glob: /;s/^Search for content: /Grep: /'
      ;;
    cursor)
      sed 's/^Search for files: /Find files: /;s/^Search for content: /Search in files: /'
      ;;
    copilot)
      sed 's/^Search for files: /Find files matching: /;s/^Search for content: /Search files for: /'
      ;;
    cline)
      sed 's/^Search for files: /Use list_files: /;s/^Search for content: /Use search_files: /'
      ;;
    aider)
      sed 's/^Search for files: /Search the codebase for files: /;s/^Search for content: /Search the codebase for: /'
      ;;
    gemini|antigravity)
      sed 's/^Search for files: /Find files: /;s/^Search for content: /Search in files: /'
      ;;
    windsurf|agents-md)
      # Keep agent-agnostic syntax as-is
      cat
      ;;
    *)
      cat
      ;;
  esac
}

# Transform agent-specific paths.
# Prompts reference .claude/ paths; map to agent-appropriate locations.
transform_paths() {
  local agent="$1"
  case "$agent" in
    claude-code)
      # No transform needed — .claude/ is native
      cat
      ;;
    cursor)
      sed 's|\.claude/|.cursor/|g'
      ;;
    copilot)
      sed 's|\.claude/|.github/|g'
      ;;
    *)
      # All others use .sdlc/
      sed 's|\.claude/|.sdlc/|g'
      ;;
  esac
}

# Transform skill reference patterns (e.g., /skill-name invocations).
# Most agents keep slash-command syntax; this is a hook for agents that differ.
transform_skill_refs() {
  local agent="$1"
  # Currently all agents use the same /skill-name pattern.
  # This function exists as a hook for future agent-specific transforms.
  cat
}

# Apply all transforms to stdin and write to stdout.
# Usage: transform_prompt "cursor" < prompt.md > output.md
transform_prompt() {
  local agent="$1"
  transform_tool_syntax "$agent" | transform_paths "$agent" | transform_skill_refs "$agent"
}
