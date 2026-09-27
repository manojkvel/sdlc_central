#!/bin/bash
# ------------------------------------------------------------------
# Shared AIDLC hook installation — sourced by setup/install-*.sh, update.sh, uninstall.sh
# ------------------------------------------------------------------
#   agent_dir <agent>                         → .claude | .cursor | .github | .sdlc
#   hook_support_level <agent>                → enforcing | advisory
#   emit_hooks <agent> <sdlc-root> <project>  → installs hook scripts and, where enforcing, wires them
#   remove_hooks <agent> <project>            → removes hook scripts and only the aidlc- hook entries
# Phase 1 of the delivery plan: Claude Code enforces; every other agent is advisory
# (scripts installed, run by the pipeline runner and CI rather than by the agent).
# ------------------------------------------------------------------

agent_dir() {
  case "$1" in
    claude-code) echo ".claude" ;;
    cursor) echo ".cursor" ;;
    copilot) echo ".github" ;;
    *) echo ".sdlc" ;;
  esac
}

hook_support_level() {
  case "$1" in
    claude-code) echo "enforcing" ;;
    *) echo "advisory" ;;
  esac
}

# Evidence tools (recorder, verifier) and their library: installed even with --no-hooks.
_copy_tools() {
  local src="$1" dst="$2"
  mkdir -p "$dst/_lib" "$dst/_bin"
  cp "$src"/_lib/*.sh "$dst/_lib/"
  cp "$src"/_bin/*.sh "$dst/_bin/"
  if [ "${EXPERIMENTAL:-0}" = 1 ]; then
    for f in console.html bench.html bench.js; do [ -f "$src/../console/$f" ] && cp "$src/../console/$f" "$dst/_bin/$f"; done
  else
    # Frozen tools (hub, console, bench, knowledge) are not part of the default install.
    local root; root="$(cd "$src/.." && pwd)"
    . "$root/adapters/_shared/support.sh"
    for f in $(support_list "$root" tools experimental); do rm -f "$dst/_bin/$f"; done
  fi
  chmod +x "$dst"/_bin/*.sh "$dst"/_lib/*.sh
}

emit_tools() {
  local agent="$1" root="$2" project="$3"
  _copy_tools "$root/hooks" "$project/$(agent_dir "$agent")/hooks"
  echo "  ✓ evidence tools: $(agent_dir "$agent")/hooks/_bin/aidlc-evidence.sh, aidlc-verify.sh"
}

_copy_hook_tree() {
  local src="$1" dst="$2" d
  _copy_tools "$src" "$dst"
  for d in "$src"/aidlc-*/; do
    d="${d%/}"
    mkdir -p "$dst/$(basename "$d")"
    cp "$d"/*.sh "$d"/hook.yaml "$dst/$(basename "$d")/"
  done
  chmod +x "$dst"/*/*.sh "$dst"/_lib/*.sh 2>/dev/null
}

emit_hooks() {
  local agent="$1" root="$2" project="$3" adir level count
  adir="$project/$(agent_dir "$agent")"
  level="$(hook_support_level "$agent")"
  _copy_hook_tree "$root/hooks" "$adir/hooks"
  [ "$agent" = "claude-code" ] && cp "$root/adapters/claude-code/hooks/wrap.sh" "$adir/hooks/wrap.sh"
  bash "$adir/hooks/_bin/aidlc-integrity.sh" --write >/dev/null
  count=$(ls -d "$adir"/hooks/aidlc-*/ 2>/dev/null | wc -l | tr -d ' ')

  if [ "$agent" = "claude-code" ]; then
    cp "$root/adapters/claude-code/hooks/wrap.sh" "$adir/hooks/wrap.sh"
    chmod +x "$adir/hooks/wrap.sh"
    if ! command -v jq >/dev/null 2>&1; then
      echo "  ! jq not found: hook scripts installed but not wired into .claude/settings.json"
      echo "  ○ hooks: $count scripts (advisory until jq is installed and setup/update.sh is re-run)"
      return 0
    fi
    local settings="$adir/settings.json" tmp
    [ -f "$settings" ] || echo '{}' > "$settings"
    tmp="$(mktemp)"
    if jq -s '
      .[0] as $cur | .[1] as $add
      | $cur
      | .hooks = (reduce ($add.hooks | keys[]) as $ev (($cur.hooks // {});
          .[$ev] = (((.[$ev] // [])
                      | map(select(((.hooks // []) | map(.command // "" | contains("/hooks/wrap.sh")) | any) | not)))
                    + $add.hooks[$ev])))
    ' "$settings" "$root/adapters/claude-code/hooks/settings.hooks.json" > "$tmp"; then
      cat "$tmp" > "$settings"
      echo "  ✓ hooks: $count scripts wired into .claude/settings.json (enforcing)"
    else
      echo "  ! could not merge .claude/settings.json (invalid JSON?); hooks installed but not wired"
    fi
    rm -f "$tmp"
  else
    cat > "$adir/hooks/README.md" <<EOF
# AIDLC hooks (advisory on $agent)

$agent has no pre-write or prompt hook event that sdlc_central wires today, so these
scripts do not run automatically. The pipeline runner calls them at each step, and the
CI template runs the artifact checks on every pull request.

Run the phase checks yourself before claiming a stage complete:

    bash $(agent_dir "$agent")/hooks/aidlc-phase-quality-gate/aidlc-phase-quality-gate.sh

Record a gate decision (the runner does this for you when a checkpoint is open):

    echo '{"prompt":"APPROVE PLAN"}' | bash $(agent_dir "$agent")/hooks/aidlc-human-approval-guard/aidlc-human-approval-guard.sh --as "<name>" --role "<role>"
EOF
    echo "  ✓ hooks: $count scripts installed to $(agent_dir "$agent")/hooks (advisory on $agent)"
  fi
}

remove_hooks() {
  local agent="$1" project="$2" adir
  adir="$project/$(agent_dir "$agent")"
  if [ -d "$adir/hooks" ]; then
    rm -rf "$adir"/hooks/aidlc-* "$adir/hooks/_lib" "$adir/hooks/_bin" "$adir/hooks/wrap.sh" "$adir/hooks/README.md" "$adir/hooks/MANIFEST.sha256"
    rmdir "$adir/hooks" 2>/dev/null
    echo "  ✓ Removed AIDLC hook scripts"
  fi
  if [ "$agent" = "claude-code" ] && [ -f "$adir/settings.json" ] && command -v jq >/dev/null 2>&1; then
    local tmp; tmp="$(mktemp)"
    jq 'if .hooks then .hooks |= (with_entries(.value |= map(select(((.hooks // []) | map(.command // "" | contains("/hooks/wrap.sh")) | any) | not))) | with_entries(select(.value | length > 0))) else . end
        | if (.hooks // {}) == {} then del(.hooks) else . end' "$adir/settings.json" > "$tmp" && cat "$tmp" > "$adir/settings.json"
    rm -f "$tmp"
    echo "  ✓ Removed AIDLC hook entries from .claude/settings.json (other entries kept)"
  fi
}
