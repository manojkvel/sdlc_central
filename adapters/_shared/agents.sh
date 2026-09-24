#!/bin/bash
# ------------------------------------------------------------------
# Shared AIDLC persona installation — sourced by setup/install-*.sh
# ------------------------------------------------------------------
#   emit_agents <agent> <sdlc-root> <project>
# Universal format: agents/<name>/agent.yaml + prompt.md. Output per agent:
#   claude-code  .claude/agents/<name>.md       (subagent: name, description, tools, model)
#   cursor       .cursor/rules/aidlc-<name>.mdc  (rule, alwaysApply: false)
#   copilot      .github/agents/<name>.agent.md  (custom agent)
#   others       .sdlc/agents/<name>.md + .sdlc/agents/README.md index (advisory persona)
# ------------------------------------------------------------------

_agent_field() { grep -E "^$2:" "$1" | head -1 | sed -E "s/^$2:[[:space:]]*//; s/^\"(.*)\"$/\\1/"; }

emit_agents() {
  local agent="$1" root="$2" project="$3" dir n=0 name y desc tools hint model body out
  local mm="$root/adapters/claude-code/model-mappings.yaml"
  [ -d "$root/agents" ] || return 0
  for dir in "$root"/agents/aidlc-*/; do
    dir="${dir%/}"; name="$(basename "$dir")"; y="$dir/agent.yaml"
    [ -f "$y" ] && [ -f "$dir/prompt.md" ] || continue
    desc="$(_agent_field "$y" description)"; tools="$(_agent_field "$y" tools)"; hint="$(_agent_field "$y" model_hint)"
    body="$(cat "$dir/prompt.md")"
    case "$agent" in
      claude-code)
        model="$(grep -E "^${hint:-default}:" "$mm" 2>/dev/null | sed 's/^[^:]*:[[:space:]]*//')"; [ -z "$model" ] && model="inherit"
        out="$project/.claude/agents/$name.md"; mkdir -p "$(dirname "$out")"
        # Subagent frontmatter takes plain tool names; Bash command patterns stay enforced by the hooks.
        tools="$(printf '%s' "$tools" | sed -E 's/\([^)]*\)//g; s/[[:space:]]+,/,/g')"
        printf -- '---\nname: %s\ndescription: %s\ntools: %s\nmodel: %s\n---\n\n%s\n' "$name" "$desc" "$tools" "$model" "$body" > "$out" ;;
      cursor)
        out="$project/.cursor/rules/$name.mdc"; mkdir -p "$(dirname "$out")"
        printf -- '---\ndescription: "AIDLC persona %s — %s"\nalwaysApply: false\n---\n\n%s\n' "$name" "$desc" "$body" > "$out" ;;
      copilot)
        out="$project/.github/agents/$name.agent.md"; mkdir -p "$(dirname "$out")"
        printf -- '---\nname: %s\ndescription: "%s"\n---\n\n%s\n' "$name" "$desc" "$body" > "$out" ;;
      *)
        out="$project/.sdlc/agents/$name.md"; mkdir -p "$(dirname "$out")"
        printf '%s\n' "$body" | sed 's|\.claude/|.sdlc/|g' > "$out" ;;
    esac
    n=$((n+1))
  done
  if [ "$agent" != "claude-code" ] && [ "$agent" != "cursor" ] && [ "$agent" != "copilot" ]; then
    {
      echo "# AIDLC personas"
      echo ""
      echo "This agent has no native subagents, so adopt a persona by reading its file before acting."
      echo "The orchestrator's routing table (aidlc-orchestrator.md) says which persona serves each stage."
      echo ""
      for dir in "$root"/agents/aidlc-*/; do
        name="$(basename "${dir%/}")"
        echo "- **$name** — $(_agent_field "$dir/agent.yaml" description) (\`.sdlc/agents/$name.md\`)"
      done
    } > "$project/.sdlc/agents/README.md"
  fi
  echo "  ✓ personas: $n installed for $agent"
}
