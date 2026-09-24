#!/bin/bash
# aidlc-integrity — are the installed hooks the ones the installer put there?
# Usage: aidlc-integrity.sh [--write]
#   --write  (installer only) record MANIFEST.sha256 for every hook and tool file
#   default  verify: every file matches the manifest, no hook is missing, and on Claude Code
#            every hook is still wired in .claude/settings.json. Exit 2 on any mismatch.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"   # <agent-dir>/hooks
MAN="$HERE/MANIFEST.sha256"
cd "$HERE" || exit 1
if [ "$1" = "--write" ]; then
  find . -type f \( -name '*.sh' -o -name 'hook.yaml' \) ! -path './_test/*' | sort | xargs shasum -a 256 > "$MAN"
  echo "  ✓ hook manifest: $(wc -l < "$MAN" | tr -d ' ') files"
  exit 0
fi
[ -f "$MAN" ] || { echo "AIDLC INTEGRITY I01: no MANIFEST.sha256 in $HERE; re-run setup/update.sh" >&2; exit 2; }
BAD="$(shasum -a 256 -c "$MAN" 2>/dev/null | grep -v ': OK$')"
if [ -n "$BAD" ]; then echo "AIDLC INTEGRITY I02: hook files differ from the installed manifest:" >&2; echo "$BAD" >&2; exit 2; fi
PROJECT="$(cd "$HERE/../.." && pwd)"; AD="$(basename "$(dirname "$HERE")")"
if [ "$AD" = ".claude" ] && [ -f "$HERE/wrap.sh" ]; then
  for h in aidlc-pre-write-guard aidlc-pre-command-guard aidlc-human-approval-guard aidlc-artifact-hygiene aidlc-final-verification; do
    grep -q "$h" "$PROJECT/.claude/settings.json" 2>/dev/null || { echo "AIDLC INTEGRITY I03: $h is no longer wired in .claude/settings.json" >&2; exit 2; }
  done
fi
echo "I00 hooks intact ($(wc -l < "$MAN" | tr -d ' ') files)"
