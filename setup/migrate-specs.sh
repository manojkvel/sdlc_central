#!/bin/bash
# ------------------------------------------------------------------
# SDLC Central — migrate existing artifacts into the AIDLC track root
# ------------------------------------------------------------------
#   specs/NNN-slug/{spec,plan,tasks}.md → <track>/phases/NN-slug/{SPEC,PLAN,TASKS}.md
#   decision-log.md                     → <track>/decisions.md (appended)
#   gate-history.json                   → <track>/gate-history.json
#   <agent>/pipelines/pipeline-state-*.json → <track>/runs/
# Every move is copied (never deleted) and logged in lineage with its hash, so
# --reverse can restore the originals byte for byte.
#
# Usage (from the project root):
#   bash setup/migrate-specs.sh [--dry-run] [--from <dir>] [--reverse] [--track-root <path>]
#     --from .planning   import a reference aidlc-agent .planning/ tree instead of specs/
# ------------------------------------------------------------------
set -e
PROJECT_DIR="$(pwd)"
DRY=0; REVERSE=0; FROM="specs"; TRACK_ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --reverse) REVERSE=1; shift ;;
    --from) FROM="$2"; shift 2 ;;
    --track-root) TRACK_ROOT="$2"; shift 2 ;;
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
T="$PROJECT_DIR/$TRACK_ROOT"
LIN="$T/lineage.md"
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
if command -v shasum >/dev/null 2>&1; then hash() { shasum -a 256 "$1" | cut -c1-64; }; else hash() { sha256sum "$1" | cut -c1-64; }; fi

if [ ! -f "$T/state.md" ] && [ $DRY -eq 0 ] && [ $REVERSE -eq 0 ]; then
  echo "No track root at $TRACK_ROOT. Run setup/init-track.sh first." >&2; exit 1
fi

# ---------------- reverse ----------------
if [ $REVERSE -eq 1 ]; then
  [ -f "$LIN" ] || { echo "No lineage.md; nothing to reverse." >&2; exit 1; }
  grep -E '\| stage\.migrated: ' "$LIN" | while IFS= read -r line; do
    src="$(printf '%s' "$line" | sed -E 's/.*stage\.migrated: ([^ ]+) -> .*/\1/')"
    dst="$(printf '%s' "$line" | awk -F' \\| ' '{print $4}')"
    want="$(printf '%s' "$line" | awk -F' \\| ' '{print $5}' | sed 's/^sha256://')"
    [ -f "$PROJECT_DIR/$dst" ] || { echo "  ✗ $dst missing; cannot restore $src"; continue; }
    got="$(hash "$PROJECT_DIR/$dst")"
    if [ "$got" != "$want" ]; then echo "  ! $dst changed since migration (hash differs); restoring its current content to $src"; fi
    if [ $DRY -eq 1 ]; then echo "  would restore $dst -> $src"; continue; fi
    mkdir -p "$(dirname "$PROJECT_DIR/$src")"
    [ -f "$PROJECT_DIR/$src" ] || cp "$PROJECT_DIR/$dst" "$PROJECT_DIR/$src"
    echo "  ✓ $src"
  done
  exit 0
fi

# ---------------- forward ----------------
COUNT=0
move() {
  local src="$1" dst="$2"
  [ -f "$PROJECT_DIR/$src" ] || return 0
  if [ -f "$PROJECT_DIR/$dst" ]; then echo "  ○ $dst exists — skipped"; return 0; fi
  if [ $DRY -eq 1 ]; then echo "  would copy $src -> $dst"; COUNT=$((COUNT+1)); return 0; fi
  mkdir -p "$(dirname "$PROJECT_DIR/$dst")"
  cp "$PROJECT_DIR/$src" "$PROJECT_DIR/$dst"
  printf '%s | - | stage.migrated: %s -> %s | %s | sha256:%s | model=none | sdlc=2.0.0-alpha\n' \
    "$(now)" "$src" "$dst" "$dst" "$(hash "$PROJECT_DIR/$dst")" >> "$LIN"
  echo "  ✓ $src -> $dst"; COUNT=$((COUNT+1))
}

if [ "$FROM" = "specs" ]; then
  for d in "$PROJECT_DIR"/specs/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    num="$(printf '%s' "$name" | sed -E 's/^([0-9]+)-.*/\1/')"; slug="$(printf '%s' "$name" | sed -E 's/^[0-9]+-//')"
    case "$num" in ''|*[!0-9]*) num=1; slug="$name" ;; esac
    phase="$(printf '%02d' "$((10#$num))")-$slug"
    for pair in spec.md:SPEC.md plan.md:PLAN.md tasks.md:TASKS.md traceability-matrix.md:TRACEABILITY.md; do
      move "specs/$name/${pair%%:*}" "$TRACK_ROOT/phases/$phase/${pair##*:}"
    done
    for v in "$d"spec.v*.md; do [ -f "$v" ] && move "specs/$name/$(basename "$v")" "$TRACK_ROOT/phases/$phase/SPEC.$(basename "$v" | sed 's/^spec\.//')"; done
  done
  move "decision-log.md" "$TRACK_ROOT/imported/decision-log.md"
  move "gate-history.json" "$TRACK_ROOT/gate-history.json"
  for s in "$PROJECT_DIR"/.claude/pipelines/pipeline-state-*.json "$PROJECT_DIR"/.sdlc/pipelines/pipeline-state-*.json; do
    [ -f "$s" ] && move "$(printf '%s' "$s" | sed "s#^$PROJECT_DIR/##")" "$TRACK_ROOT/runs/$(basename "$s")"
  done
else
  # A reference aidlc-agent tree (for example .planning/): same layout, copy as is.
  [ -d "$PROJECT_DIR/$FROM" ] || { echo "No $FROM directory." >&2; exit 1; }
  (cd "$PROJECT_DIR/$FROM" && find . -type f) | sed 's#^\./##' | while IFS= read -r f; do
    case "$f" in state.md|human-decisions.md|lineage.md|requirements.md|decisions.md|risks.md|roadmap.md)
      if [ -f "$PROJECT_DIR/$TRACK_ROOT/$f" ]; then
        if [ $DRY -eq 1 ]; then echo "  would import $FROM/$f -> $TRACK_ROOT/imported/$f"; continue; fi
        move "$FROM/$f" "$TRACK_ROOT/imported/$f"; continue
      fi ;;
    esac
    move "$FROM/$f" "$TRACK_ROOT/$f"
  done
fi

echo ""
if [ $DRY -eq 1 ]; then echo "Dry run: $COUNT file(s) would be copied. Nothing was changed."
else
  echo "Migrated $COUNT file(s). Originals were kept. Check with:"
  echo "  bash <agent-dir>/hooks/aidlc-artifact-consistency-check/aidlc-artifact-consistency-check.sh --all"
  echo "  bash <agent-dir>/hooks/aidlc-traceability-check/aidlc-traceability-check.sh --all"
  echo "Gates already passed in old state files can be backfilled by the runner as HD records marked BACKFILLED."
fi
