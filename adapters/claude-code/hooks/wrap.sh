#!/bin/bash
# Claude Code → AIDLC hook contract adapter.
# Usage (from .claude/settings.json): wrap.sh <write|command|prompt|stop> <hook-name>
# Converts Claude Code's hook payload into {event, tool, path|command|prompt, cwd, ...},
# runs .claude/hooks/<hook-name>/<hook-name>.sh, and passes its exit code through:
#   0 allow · 2 block (stderr is fed back to Claude, or shown to the user for prompts) · other = non-blocking error
KIND="$1"; HOOK="$2"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$DIR/$HOOK/$HOOK.sh"
[ -f "$SCRIPT" ] || { echo "AIDLC WARN: hook $HOOK not installed" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "AIDLC WARN: jq not found; $HOOK skipped" >&2; exit 1; }
RAW="$(cat)"
case "$KIND" in
  write)   FILTER='{event: (if .hook_event_name=="PostToolUse" then "post-write" else "pre-write" end), tool:"write", path:(.tool_input.file_path // .tool_input.notebook_path // .tool_input.path // ""), cwd}' ;;
  command) FILTER='{event:"pre-command", tool:"command", command:(.tool_input.command // ""), cwd}' ;;
  prompt)  FILTER='{event:"prompt", tool:"prompt", prompt:(.prompt // ""), cwd}' ;;
  stop)    FILTER='{event:"stop", tool:"stop", transcript_path:(.transcript_path // ""), stop_hook_active:(.stop_hook_active // false), cwd}' ;;
  *) echo "AIDLC WARN: unknown hook kind $KIND" >&2; exit 1 ;;
esac
printf '%s' "$RAW" | jq -c "$FILTER" 2>/dev/null | AIDLC_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}" bash "$SCRIPT"
exit ${PIPESTATUS[2]:-$?}
