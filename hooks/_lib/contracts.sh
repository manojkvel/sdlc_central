#!/bin/bash
# ------------------------------------------------------------------
# AIDLC contract library — sourced by the contract registry tool, the pre-write guard (W09)
# and the scorecard (D5). Requires _lib/track-parse.sh to be sourced first.
# ------------------------------------------------------------------
# Contract file: <hub track>/contracts/C-NNN.md with front matter
#   id, kind, producer (WS-NNN), consumers [WS-...], schema, test_command, version,
#   status (DRAFT | APPROVED_WITH_RISK | APPROVED | BREACHED | SUPERSEDED),
#   approved_by_decision, last_test (PASS|FAIL <ISO time>)
# Status flow:
#   DRAFT --APPROVE WORKSTREAM CONTRACT WITH RISK--> APPROVED_WITH_RISK   (consumers may build; release claims excluded)
#   DRAFT --APPROVE WORKSTREAM CONTRACT + green test--> APPROVED
#   APPROVED_WITH_RISK --green test--> APPROVED (propose LIFT EXCLUSION to consumers)
#   APPROVED --red test--> BREACHED --green test--> APPROVED
# ------------------------------------------------------------------

# Hub track root for a unit: unit.yaml `hub:` (path to the hub repo, relative to the project) or this project.
contract_hub_track() {
  local unit="$1" hub
  hub="$(grep -E '^hub:' "$unit" 2>/dev/null | sed 's/^hub:[[:space:]]*//; s/[[:space:]]*$//')"
  if [ -z "$hub" ]; then echo "$AIDLC_TRACK"; return; fi
  case "$hub" in /*) ;; *) hub="$AIDLC_PROJECT/$hub" ;; esac
  if [ -d "$hub/.track" ]; then echo "$(cd "$hub/.track" && pwd)"; else echo "$(cd "$hub" 2>/dev/null && pwd)"; fi
}

contract_field() { # contract_field <file> <key>
  awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f' "$1" 2>/dev/null | grep -E "^$2:" | head -1 \
    | sed -E "s/^$2:[[:space:]]*//; s/^[\"']//; s/[\"']$//; s/[[:space:]]*$//"
}

contract_set_field() { # contract_set_field <file> <key> <value>
  local f="$1" k="$2" v="$3" tmp; tmp="$(mktemp)"
  awk -v k="$k" -v v="$v" 'NR==1 && /^---$/ {print; f=1; next}
    f && /^---$/ { if (!done) print k ": " v; print; f=0; next }
    f && index($0, k ":") == 1 { print k ": " v; done=1; next } {print}' "$f" > "$tmp" && cat "$tmp" > "$f"
  rm -f "$tmp"
}

unit_list() { # unit_list <unit.yaml> <key>  → one id per line
  grep -E "^$2:" "$1" 2>/dev/null | grep -Eo 'C-[0-9]+|WS-[0-9]+'
}

# contract_check_unit <unit.yaml> → prints one line per consumed contract:
#   OK C-001 · EXCLUDED C-002 <reason> · BLOCKED C-003 <status>
# returns 0 all OK, 3 at least one EXCLUDED and none BLOCKED, 2 any BLOCKED.
contract_check_unit() {
  local unit="$1" hub c f st rc=0
  hub="$(contract_hub_track "$unit")"
  for c in $(unit_list "$unit" consumes); do
    f="$hub/contracts/$c.md"
    if [ ! -f "$f" ]; then echo "BLOCKED $c unregistered"; rc=2; continue; fi
    st="$(contract_field "$f" status)"
    case "$st" in
      APPROVED) echo "OK $c" ;;
      APPROVED_WITH_RISK) echo "EXCLUDED $c approved with risk by $(contract_field "$f" approved_by_decision)"; [ $rc -eq 0 ] && rc=3 ;;
      *) echo "BLOCKED $c ${st:-no status}"; rc=2 ;;
    esac
  done
  return $rc
}

# Mark a consumer unit as building on risk-accepted contracts.
unit_set_excluded() { # unit_set_excluded <unit.yaml> <true|false>
  local u="$1" v="$2"
  if grep -q '^release_claims_excluded:' "$u"; then
    sed -i.bak "s/^release_claims_excluded:.*/release_claims_excluded: $v/" "$u" && rm -f "$u.bak"
  else echo "release_claims_excluded: $v" >> "$u"; fi
}
