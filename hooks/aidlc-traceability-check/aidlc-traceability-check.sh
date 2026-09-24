#!/bin/bash
# aidlc-traceability-check — id mapping across the phase artifacts.
#   T01 orphan requirement : a REQ in requirements.md that no SPEC.md references
#   T02 unmapped criterion : an AC or SC in SPEC.md missing from PLAN.md, or from VERIFICATION.md when it exists
#   T03 dangling id        : a D, DEC or RISK id referenced in the phase but not defined
#   T04 untraced task      : a TASK in TASKS.md whose line names no AC or SC
# Modes: hook (after a write to PLAN.md, TASKS.md or VERIFICATION.md), --phase <NN-slug>, --all.
# Prints "T00 traced" on success.
AIDLC_HOOK_NAME="aidlc-traceability-check"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
aidlc_require_jq

MODE="hook"; ONE_PHASE=""
case "$1" in
  --all) MODE="all"; AIDLC_INPUT='{}' ;;
  --phase) MODE="phase"; ONE_PHASE="$2"; AIDLC_INPUT='{}' ;;
  *) aidlc_read_input ;;
esac
aidlc_load_state
aidlc_active || exit 0

if [ "$MODE" = "hook" ]; then
  T="$(aidlc_field .path)"
  case "$(basename "${T:-x}")" in PLAN.md|TASKS.md|VERIFICATION.md|SPEC.md) ;; *) exit 0 ;; esac
  case "$T" in */phases/*) ONE_PHASE="$(printf '%s' "$T" | sed -E 's#.*/phases/([^/]+)/.*#\1#')" ;; *) exit 0 ;; esac
fi

ids() { grep -Eo "$1" "$2" 2>/dev/null | sort -u; }
FAILS=""
fail() { FAILS="$FAILS
$1 $2"; }

check_phase() {
  local dir="$1" name spec plan tasks ver id t
  name="$(basename "$dir")"
  spec="$dir/SPEC.md"; plan="$dir/PLAN.md"; tasks="$dir/TASKS.md"; ver="$dir/VERIFICATION.md"
  # Tier 1 inline units are exempt.
  [ -f "$dir/unit.md" ] && [ ! -f "$spec" ] && return 0
  [ -f "$spec" ] || return 0

  for id in $(ids '(AC|SC)-[0-9]+' "$spec"); do
    if [ -f "$plan" ] && ! grep -Eq "(^|[^A-Za-z0-9-])$id([^0-9]|$)" "$plan"; then fail T02 "$name: $id not in PLAN.md"; fi
    if [ -f "$ver" ] && ! grep -Eq "(^|[^A-Za-z0-9-])$id([^0-9]|$)" "$ver"; then fail T02 "$name: $id not in VERIFICATION.md"; fi
  done

  for f in "$spec" "$plan" "$dir/TECHNICAL_DESIGN.md" "$tasks"; do
    [ -f "$f" ] || continue
    for id in $(grep -Eo '(^|[^A-Z])(D|DEC)-[0-9]+' "$f" | sed -E 's/^[^A-Z]*//' | sort -u); do
      num="${id#*-}"
      grep -Eq "(^|[^A-Z])(D|DEC)-$num([^0-9]|$)" "$AIDLC_TRACK/decisions.md" 2>/dev/null || fail T03 "$name: $id referenced in $(basename "$f") but not in decisions.md"
    done
    for id in $(ids 'RISK-[0-9]+' "$f"); do
      grep -Eq "$id([^0-9]|$)" "$AIDLC_TRACK/risks.md" 2>/dev/null || fail T03 "$name: $id referenced in $(basename "$f") but not in risks.md"
    done
  done

  if [ -f "$tasks" ]; then
    grep -E 'TASK-[0-9]+' "$tasks" | grep -E '^(#+|\||[-*])' | while IFS= read -r line; do
      t="$(printf '%s' "$line" | grep -Eo 'TASK-[0-9]+' | head -1)"
      printf '%s' "$line" | grep -Eq '(AC|SC)-[0-9]+' || echo "$t"
    done | sort -u > "${TMPDIR:-/tmp}/aidlc-untraced.$$"
    # A task heading may carry its ACs on the following lines; accept a mention anywhere in its block.
    while IFS= read -r t; do
      [ -z "$t" ] && continue
      awk -v t="$t" '$0 ~ t {f=1} f && /(AC|SC)-[0-9]+/ {ok=1} f && $0 !~ t && /TASK-[0-9]+/ {exit} END {exit ok?0:1}' "$tasks" \
        || fail T04 "$name: $t names no AC or SC"
    done < "${TMPDIR:-/tmp}/aidlc-untraced.$$"
    rm -f "${TMPDIR:-/tmp}/aidlc-untraced.$$"
  fi
}

if [ "$MODE" = "all" ]; then
  for d in "$AIDLC_TRACK"/phases/*/; do [ -d "$d" ] && check_phase "${d%/}"; done
else
  [ -z "$ONE_PHASE" ] && ONE_PHASE="$AIDLC_PHASE"
  [ "$ONE_PHASE" = "none" ] && exit 0
  check_phase "$AIDLC_TRACK/phases/$ONE_PHASE"
fi

# T01 runs over the whole track: every REQ must appear in some SPEC.md.
if [ -f "$AIDLC_TRACK/requirements.md" ] && ls "$AIDLC_TRACK"/phases/*/SPEC.md >/dev/null 2>&1; then
  for id in $(ids 'REQ-[0-9]+' "$AIDLC_TRACK/requirements.md"); do
    cat "$AIDLC_TRACK"/phases/*/SPEC.md | grep -Eq "$id([^0-9]|$)" || fail T01 "$id has no SPEC.md that references it"
  done
fi

if [ -n "$FAILS" ]; then
  FIRST="$(printf '%s\n' "$FAILS" | sed '/^$/d' | head -1)"
  COUNT="$(printf '%s\n' "$FAILS" | sed '/^$/d' | wc -l | tr -d ' ')"
  printf '%s\n' "$FAILS" | sed '/^$/d' >&2
  aidlc_block "${FIRST%% *}" "$COUNT traceability gap(s); first: ${FIRST#* }" "map every listed id, then re-run the check"
fi
echo "T00 traced"
exit 0
