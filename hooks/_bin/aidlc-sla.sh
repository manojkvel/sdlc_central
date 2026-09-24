#!/bin/bash
# aidlc-sla — is the open gate waiting longer than its SLA? (scheduled CI job)
# Reads BLOCKED_GATE from state.md, the time its checkpoint was published from lineage,
# and sla_hours / escalate_to from <track>/stakeholders.yaml. Exit 2 when breached, with
# the escalation line on stdout (post it with board-sync or a chat webhook).
AIDLC_HOOK_NAME="aidlc-sla"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
AIDLC_INPUT='{}'
aidlc_load_state
aidlc_active || exit 0
[ "$AIDLC_GATE" = "none" ] && { echo "S00 no open gate"; exit 0; }
SH="$AIDLC_TRACK/stakeholders.yaml"
LINE="$(grep -E "^  $AIDLC_GATE:" "$SH" 2>/dev/null)"
SLA="$(printf '%s' "$LINE" | grep -Eo 'sla_hours: *[0-9]+' | grep -Eo '[0-9]+')"; SLA="${SLA:-48}"
ESC="$(printf '%s' "$LINE" | sed -n 's/.*escalate_to: *\[\([^]]*\)\].*/\1/p')"
PUB="$(grep -F "decision.checkpoint_published: $AIDLC_GATE" "$AIDLC_TRACK/lineage.md" | tail -1 | cut -d' ' -f1)"
[ -z "$PUB" ] && { echo "S01 gate $AIDLC_GATE open but no checkpoint_published event in lineage"; exit 2; }
AGE_H=$(( ( $(date -u +%s) - $(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$PUB" +%s 2>/dev/null || date -u -d "$PUB" +%s) ) / 3600 ))
if [ $AGE_H -gt $SLA ]; then
  echo "S02 ESCALATE: gate $AIDLC_GATE on phase $AIDLC_PHASE has waited ${AGE_H}h (SLA ${SLA}h). Escalate to: ${ESC:-tech-lead}. Next action: $(resume_field "$AIDLC_STATE" NEXT_ACTION)"
  aidlc_lineage "-" "decision.sla_breached: $AIDLC_GATE ${AGE_H}h" "$(aidlc_rel "$AIDLC_STATE")" "-"
  exit 2
fi
echo "S00 gate $AIDLC_GATE waiting ${AGE_H}h of ${SLA}h"
