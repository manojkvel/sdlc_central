#!/bin/bash
# aidlc-phase-quality-gate — wrapper the quality-gate skill calls at every stage transition.
# Runs traceability, consistency and hygiene over the current (or named) phase and
# returns the first failing code. Prints "Q00 phase clean" when all pass.
# Usage: aidlc-phase-quality-gate.sh [--phase NN-slug]
AIDLC_HOOK_NAME="aidlc-phase-quality-gate"
HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HOOKS/_lib/track-parse.sh"
aidlc_require_jq
AIDLC_INPUT='{}'
[ -t 0 ] || aidlc_read_input
aidlc_load_state
aidlc_active || exit 0

PH="$AIDLC_PHASE"; [ "$1" = "--phase" ] && PH="$2"
RC=0; OUT=""
run() {
  local name="$1"; shift
  local o; o="$("$@" 2>&1 </dev/null)"; local r=$?
  OUT="$OUT
[$name] $(printf '%s' "$o" | tail -5)"
  if [ $r -eq 2 ] && [ $RC -eq 0 ]; then RC=2; FIRST="$(printf '%s' "$o" | grep -Eo 'AIDLC BLOCK [a-z-]+ [A-Z][0-9]{2}: .*' | head -1)"; fi
}
run traceability bash "$HOOKS/aidlc-traceability-check/aidlc-traceability-check.sh" --phase "$PH"
run consistency  bash "$HOOKS/aidlc-artifact-consistency-check/aidlc-artifact-consistency-check.sh" --all
run hygiene      bash "$HOOKS/aidlc-artifact-hygiene/aidlc-artifact-hygiene.sh" --all

printf '%s\n' "$OUT" | sed '/^$/d'
if [ $RC -eq 2 ]; then
  echo "AIDLC BLOCK $AIDLC_HOOK_NAME Q01: phase $PH failed its quality gate — ${FIRST#AIDLC BLOCK }" >&2
  exit 2
fi
echo "Q00 phase clean"
exit 0
