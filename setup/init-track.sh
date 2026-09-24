#!/bin/bash
# ------------------------------------------------------------------
# SDLC Central — initialise the AIDLC track root
# ------------------------------------------------------------------
# Creates the track root (default .track/) with state.md, human-decisions.md,
# lineage.md, requirements.md, decisions.md, risks.md, roadmap.md and a
# .gitignore for evidence log bodies. Idempotent: never overwrites a file.
# Hooks are inert until this has run.
#
# Usage (from the project root):
#   bash /path/to/sdlc_central/setup/init-track.sh [--track-root <path>] [--hub]
#     --hub   also create the hub files (workstream map, contract registry,
#             dependency map, contracts/, central TECHNICAL_DESIGN.md)
# ------------------------------------------------------------------
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDLC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$(pwd)"
TPL="$SDLC_ROOT/templates/track"
TRACK_ROOT=""; HUB=0
while [ $# -gt 0 ]; do
  case "$1" in
    --track-root) TRACK_ROOT="$2"; shift 2 ;;
    --track-root=*) TRACK_ROOT="${1#*=}"; shift ;;
    --hub) HUB=1; shift ;;
    *) shift ;;
  esac
done

if [ -z "$TRACK_ROOT" ]; then
  for d in .claude .sdlc .cursor .github; do
    if [ -f "$PROJECT_DIR/$d/sdlc-central.json" ] && command -v jq >/dev/null 2>&1; then
      TRACK_ROOT="$(jq -r '.track_root // empty' "$PROJECT_DIR/$d/sdlc-central.json")"; break
    fi
  done
fi
[ -z "$TRACK_ROOT" ] && TRACK_ROOT=".track"
case "$TRACK_ROOT" in /*) T="$TRACK_ROOT" ;; *) T="$PROJECT_DIR/$TRACK_ROOT" ;; esac

echo "Initialising AIDLC track root at $TRACK_ROOT"
mkdir -p "$T/phases" "$T/runs"
place() {
  local src="$1" dst="$2"
  if [ -f "$dst" ]; then echo "  ○ $(basename "$dst") (exists — preserved)"
  else cp "$src" "$dst"; echo "  ✓ $(basename "$dst")"; fi
}
for f in state.md human-decisions.md lineage.md requirements.md decisions.md risks.md roadmap.md; do
  place "$TPL/$f" "$T/$f"
done
place "$TPL/gitignore" "$T/.gitignore"

if [ $HUB -eq 1 ]; then
  mkdir -p "$T/contracts"
  for f in workstream-map.md contract-registry.md dependency-map.md TECHNICAL_DESIGN.md; do
    place "$TPL/hub/$f" "$T/$f"
  done
fi

if ! grep -q 'stage.entered: intake' "$T/lineage.md" 2>/dev/null; then
  printf '%s | - | stage.entered: intake | %s/state.md | sha256:- | model=none | sdlc=2.0.0-alpha\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TRACK_ROOT" >> "$T/lineage.md"
fi

echo ""
echo "Track root ready. Hooks installed by setup/install-*.sh are now active for this project."
echo "Next: /run-pipeline aidlc/unit-of-work \"<request>\", or create $TRACK_ROOT/phases/01-<slug>/unit.md for a tier 1 fix."
