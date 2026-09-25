#!/bin/bash
# aidlc-artifact-consistency-check — contradictions across the audit rail.
#   X01 state drift            : CURRENT_PHASE has no directory, or CURRENT_STAGE disagrees with the last stage event
#   X02 approved artifact changed : an artifact's hash differs from the hash recorded when its decision was accepted
#   X03 summary contradicts verification : SUMMARY.md claims completion while VERIFICATION.md has FAIL rows
#   X04 decision without lineage : an HD record in human-decisions.md with no lineage line
#   X05 unknown event family    : a lineage event outside stage, decision, evidence, contract, handoff, knowledge, guardrail, cost
# Modes: hook (on stop, or invoked by the phase quality gate), --all.
# Prints "X00 consistent" on success.
AIDLC_HOOK_NAME="aidlc-artifact-consistency-check"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
aidlc_require_jq

if [ "$1" = "--all" ] || [ "$1" = "--phase" ]; then AIDLC_INPUT='{}'; else aidlc_read_input; fi
aidlc_load_state
aidlc_active || exit 0
[ "$(aidlc_field .stop_hook_active)" = "true" ] && exit 0

LIN="$AIDLC_TRACK/lineage.md"
HDF="$AIDLC_TRACK/human-decisions.md"
FAILS=""
fail() { FAILS="$FAILS
$1 $2"; }

# X01
if [ "$AIDLC_PHASE" != "none" ] && [ ! -d "$AIDLC_PHASE_DIR" ]; then
  fail X01 "CURRENT_PHASE $AIDLC_PHASE has no directory under phases/"
fi
if [ -f "$LIN" ] && [ "$AIDLC_PHASE" != "none" ]; then
  LAST_STAGE="$(grep -F "$AIDLC_PHASE" "$LIN" | grep -Eo 'stage\.entered: [a-z]+' | tail -1 | sed 's/stage\.entered: //')"
  if [ -n "$LAST_STAGE" ] && [ -n "$AIDLC_STAGE" ] && [ "$LAST_STAGE" != "$AIDLC_STAGE" ]; then
    fail X01 "state.md stage $AIDLC_STAGE but lineage last entered $LAST_STAGE for $AIDLC_PHASE"
  fi
fi

if [ -f "$LIN" ]; then
  # X05: event families. Lines look like: ts | ref | family.event: detail | artifact | sha256:x | ...
  BAD="$(grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$LIN" | awk -F' \\| ' '{print $3}' | sed -E 's/:.*//' \
        | grep -Ev '^(stage|decision|evidence|contract|handoff|knowledge|guardrail|cost)\.[a-z_]+$' | grep -Ev '^[A-Z_]+$' | head -1)"
  [ -n "$BAD" ] && fail X05 "unknown lineage event '$BAD'"

  # X02: latest accepted-decision hash per artifact vs the file today.
  grep -E '\| decision\.(accepted|approved_with_risk|lifted_exclusion)' "$LIN" | awk -F' \\| ' '{print $4"\t"$5}' \
    | awk -F'\t' '{h[$1]=$2} END {for (a in h) print a"\t"h[a]}' | while IFS="$(printf '\t')" read -r art h; do
      [ -z "$art" ] || [ "$art" = "-" ] && continue
      case "$art" in */risks.md) continue ;; esac
      want="${h#sha256:}"; [ "$want" = "-" ] && continue
      now="$(aidlc_artifact_hash "$(aidlc_abs "$art")")"
      [ "$now" != "$want" ] && echo "X02 approved artifact $art changed after approval"
    done > "${TMPDIR:-/tmp}/aidlc-x02.$$"
  while IFS= read -r l; do [ -n "$l" ] && fail "${l%% *}" "${l#* }"; done < "${TMPDIR:-/tmp}/aidlc-x02.$$"
  rm -f "${TMPDIR:-/tmp}/aidlc-x02.$$"
fi

# X04
if [ -f "$HDF" ]; then
  for hd in $(grep -Eo '^### \[HD-[0-9]+\]' "$HDF" | grep -Eo 'HD-[0-9]+'); do
    grep -q "| $hd |" "$LIN" 2>/dev/null || fail X04 "$hd has no lineage line"
  done
fi

# X03 over every phase (cheap).
for d in "$AIDLC_TRACK"/phases/*/; do
  [ -d "$d" ] || continue
  s="$d/SUMMARY.md"; v="$d/VERIFICATION.md"
  if [ -f "$s" ] && [ -f "$v" ] && grep -Eiq '(all (tasks|acceptance criteria|tests) (are )?(complete|pass|passing|done)|fully (complete|verified))' "$s" \
     && grep -Eq '\|[[:space:]]*FAIL[[:space:]]*\|' "$v"; then
    fail X03 "$(basename "$d"): SUMMARY.md claims completion but VERIFICATION.md has FAIL rows"
  fi
done

if [ -n "$FAILS" ]; then
  FIRST="$(printf '%s\n' "$FAILS" | sed '/^$/d' | head -1)"
  COUNT="$(printf '%s\n' "$FAILS" | sed '/^$/d' | wc -l | tr -d ' ')"
  printf '%s\n' "$FAILS" | sed '/^$/d' >&2
  aidlc_block "${FIRST%% *}" "$COUNT inconsistency(ies); first: ${FIRST#* }" \
    "fix the artifact, or raise REQUEST CHANGES so the changed artifact is re-approved"
fi
echo "X00 consistent"
exit 0
