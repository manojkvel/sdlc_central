#!/bin/bash
# aidlc-start — open a new unit of work: <track>/phases/NN-<slug>/ with unit.yaml (and unit.md for tier 1),
# point the resume block at it, and log stage.entered in lineage. Used by `atticus start` and the /atticus skill.
# Usage: aidlc-start.sh <slug> [--tier 1|2|3] [--profile feature|bugfix|poc|security|infra|data|migration]
#                       [--request "<one line>"] [--force]
# Refuses while a gate is open, or while another phase is active unless --force.
AIDLC_HOOK_NAME="aidlc-start"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
AIDLC_INPUT='{}'
die() { echo "aidlc-start: $*" >&2; exit 1; }
SLUG=""; TIER=""; PROFILE=""; FORCE=0; REQ=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tier) TIER="$2"; shift 2 ;; --profile) PROFILE="$2"; shift 2 ;;
    --request) REQ="$2"; shift 2 ;; --force) FORCE=1; shift ;;
    -*) die "unknown option $1" ;; *) SLUG="$SLUG${SLUG:+-}$1"; shift ;;
  esac
done
[ -n "$SLUG" ] || die "usage: aidlc-start.sh <slug> [--tier 1|2|3] [--profile P] [--request \"...\"]"
SLUG="$(printf '%s' "$SLUG" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-' | cut -c1-40 | sed 's/-*$//')"
aidlc_load_state
aidlc_active || die "no $(aidlc_rel "$AIDLC_STATE") here (run: atticus init)"
[ "$AIDLC_GATE" != "none" ] && die "gate $AIDLC_GATE is open on $AIDLC_PHASE; decide it first"
if [ "$AIDLC_PHASE" != "none" ] && [ "$AIDLC_STAGE" != "done" ] && [ $FORCE -eq 0 ]; then
  die "phase $AIDLC_PHASE is still active; finish it, or pass --force to switch"
fi
case "$PROFILE" in ""|feature|bugfix|poc|security|infra|data|migration) ;; *) die "unknown profile $PROFILE" ;; esac
[ -z "$TIER" ] && case "$PROFILE" in bugfix|poc) TIER=1 ;; *) TIER=2 ;; esac
case "$TIER" in 1|2|3) ;; *) die "tier must be 1, 2 or 3" ;; esac
[ -z "$PROFILE" ] && { [ "$TIER" = 1 ] && PROFILE=bugfix || PROFILE=feature; }

TR="$(aidlc_rel "$AIDLC_TRACK")"
mkdir -p "$AIDLC_TRACK/phases"
N="$(ls -1 "$AIDLC_TRACK/phases" 2>/dev/null | sed -n 's/^\([0-9][0-9]*\)-.*/\1/p' | sort -n | tail -1)"
N=$(( 10#${N:-0} + 1 )); NN="$(printf '%02d' "$N")"
PH="$NN-$SLUG"; D="$AIDLC_TRACK/phases/$PH"
mkdir -p "$D"
{
  printf 'id: UOW-%03d\nname: %s\nprofile: %s\ntier: %s\nrepos: [%s]\n' "$N" "$SLUG" "$PROFILE" "$TIER" "$(basename "$AIDLC_PROJECT")"
  [ -n "$REQ" ] && printf 'request: "%s"\n' "$(printf '%s' "$REQ" | tr '"\n' "' ")"
} > "$D/unit.yaml"
if [ "$TIER" = 1 ]; then
  [ -f "$D/unit.md" ] || cat > "$D/unit.md" <<UM
# $SLUG (tier 1)

## Fix
${REQ:-<one or two sentences: what is wrong and what changes>}

## Acceptance check
<the command or observation that proves it is fixed>

## Files
<paths this fix touches>
UM
  STAGE=execution; OWNER="agent:any"
  NEXT="Complete $TR/phases/$PH/unit.md, make the fix, record the test with aidlc-evidence.sh run --task TASK-001 -- <cmd>, then verify"
else
  STAGE=intake; OWNER="agent:aidlc-orchestrator"
  NEXT="Continue the aidlc/unit-of-work pipeline at the source and spec steps for $PH"
fi
set_resume_field "$AIDLC_STATE" CURRENT_PHASE "$PH"
set_resume_field "$AIDLC_STATE" CURRENT_STAGE "$STAGE"
set_resume_field "$AIDLC_STATE" BLOCKED_GATE none
set_resume_field "$AIDLC_STATE" GATE_RISK none
set_resume_field "$AIDLC_STATE" GATE_REMINDED no
set_resume_field "$AIDLC_STATE" NEXT_ACTION "$NEXT"
set_resume_field "$AIDLC_STATE" NEXT_ACTION_OWNER "$OWNER"
set_resume_field "$AIDLC_STATE" NEXT_ACTION_INPUTS "$TR/phases/$PH/unit.yaml"
set_resume_field "$AIDLC_STATE" DONE none
set_resume_field "$AIDLC_STATE" EVIDENCE none
printf '| %s | %s | %s | %s | - | - |\n' "$PH" "$STAGE" "$TIER" "$PROFILE" >> "$AIDLC_STATE"
AIDLC_MODEL=none aidlc_lineage "$PH" "stage.entered: $STAGE" "$TR/phases/$PH/unit.yaml" "$(aidlc_sha256 "$D/unit.yaml")"
echo "Started $PH (tier $TIER, profile $PROFILE, stage $STAGE)."
echo "Next: $NEXT"
