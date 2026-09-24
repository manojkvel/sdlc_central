#!/bin/bash
# ------------------------------------------------------------------
# aidlc-scorecard — the six-dimension governance scorecard that gates APPROVE RELEASE.
# ------------------------------------------------------------------
# Usage: aidlc-scorecard.sh [--phase NN-slug]
#
#   D1 Requirements & traceability   aidlc-traceability-check --phase → T00          owner: aidlc-plan-checker (architect)
#   D2 Artifact completeness/hygiene required artifacts for tier + profile; hygiene   owner: aidlc-delivery-manager
#   D3 Human approval audit          every required HITL gate before release has an    owner: aidlc-governance-reviewer (tech lead)
#                                    accepted HD record for this phase; state and
#                                    lineage consistent (X00)
#   D4 Evidence rail proof           sealed VERIFICATION.md, COMPLETE, no stale entry  owner: aidlc-verifier (developer / QA)
#   D5 Contract & workstream alignment tier 3: consumed contracts APPROVED, or accepted  owner: aidlc-governance-reviewer (architect)
#                                    with risk and release claims excluded
#   D6 Security, NFR & risk          REVIEW.md with no open CRITICAL/HIGH; no open      owner: aidlc-security-standards-reviewer
#                                    risk in risks.md without a signing HD
#
# Writes <phase>/SCORECARD.md (sealed like VERIFICATION.md) ending "## GOVERNANCE APPROVED" or
# "## GOVERNANCE BLOCKED", appends to <track>/gate-history.json and lineage.
# Exit 0 approved, 2 blocked. Deterministic: no model calls.
# ------------------------------------------------------------------
AIDLC_HOOK_NAME="aidlc-scorecard"
BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS="$(cd "$BIN/.." && pwd)"
. "$HOOKS/_lib/track-parse.sh"
aidlc_require_jq
AIDLC_INPUT='{}'
PHASE_ARG=""
while [ $# -gt 0 ]; do case "$1" in --phase) PHASE_ARG="$2"; shift 2 ;; *) shift ;; esac; done

aidlc_load_state
aidlc_active || { echo "aidlc-scorecard: no track root" >&2; exit 1; }
[ -n "$PHASE_ARG" ] && { AIDLC_PHASE="$PHASE_ARG"; AIDLC_PHASE_DIR="$AIDLC_TRACK/phases/$PHASE_ARG"; }
D="$AIDLC_PHASE_DIR"; P="$AIDLC_PHASE"
[ -d "$D" ] || { echo "aidlc-scorecard: no phase directory $P" >&2; exit 1; }
TIER="$(aidlc_tier)"
PROFILE="$(grep -E '^profile:' "$D/unit.yaml" 2>/dev/null | sed 's/^profile:[[:space:]]*//')"
AGENT_DIR="$(aidlc_agent_dir_name "$AIDLC_PROJECT")"
GC="$AIDLC_PROJECT/$AGENT_DIR/config/gate-config.json"
[ -f "$GC" ] || GC="$HOOKS/../config/gate-config.json"
PROFILES_YAML="$AIDLC_PROJECT/$AGENT_DIR/config/profiles.yaml"
[ -f "$PROFILES_YAML" ] || PROFILES_YAML="$HOOKS/../config/profiles.yaml"

ROWS=""; FAILED=0; FAILED_DIMS=""
dim() { # dim <id> <name> <PASS|FAIL|N/A> <detail> <owner>
  ROWS="$ROWS| $1 | $2 | $3 | $(printf '%s' "$4" | tr '|\n' '/ ' | cut -c1-220) | $5 |
"
  if [ "$3" = "FAIL" ]; then FAILED=$((FAILED+1)); FAILED_DIMS="$FAILED_DIMS $1"; fi
}
run_hook() { AIDLC_PROJECT_DIR="$AIDLC_PROJECT" bash "$HOOKS/$1/$1.sh" "${@:2}" </dev/null 2>&1; }

# ---------------- D1 ----------------
if [ "$TIER" = "1" ]; then dim D1 "Requirements & traceability" "N/A" "tier 1 inline unit" "aidlc-plan-checker"
else
  O="$(run_hook aidlc-traceability-check --phase "$P")"; R=$?
  if [ $R -eq 0 ]; then dim D1 "Requirements & traceability" PASS "T00 traced" "aidlc-plan-checker"
  else dim D1 "Requirements & traceability" FAIL "$(printf '%s' "$O" | grep -E '^T0[1-9]' | head -3 | tr '\n' ';')" "aidlc-plan-checker (architect)"; fi
fi

# ---------------- D2 ----------------
case "$TIER" in
  1) REQ="unit.md" ;;
  2) REQ="SPEC.md PLAN.md PLAN_CHECK.md TASKS.md VERIFICATION.md REVIEW.md" ;;
  *) REQ="SPEC.md TECHNICAL_DESIGN.md PLAN.md PLAN_CHECK.md TASKS.md VERIFICATION.md REVIEW.md" ;;
esac
if [ -n "$PROFILE" ] && [ -f "$PROFILES_YAML" ]; then
  EXTRA="$(awk -v p="  $PROFILE:" '$0==p {f=1; next} f && /^  [a-z]/ {exit} f && /required_artifacts:/ {gsub(/.*\[|\].*/,""); gsub(/,/," "); print}' "$PROFILES_YAML")"
  SKIP="$(awk -v p="  $PROFILE:" '$0==p {f=1; next} f && /^  [a-z]/ {exit} f && /skip_artifacts:/ {gsub(/.*\[|\].*/,""); gsub(/,/," "); print}' "$PROFILES_YAML")"
  for x in $EXTRA; do case " $REQ " in *" $x "*) ;; *) REQ="$REQ $x" ;; esac; done
  for x in $SKIP; do REQ="$(printf ' %s ' "$REQ" | sed "s/ $x / /g")"; done
fi
grep -Eq '^produces:.*C-[0-9]' "$D/unit.yaml" 2>/dev/null && REQ="$REQ CONTRACT_EVIDENCE.md"
MISSING=""; for f in $REQ; do [ -f "$D/$f" ] || MISSING="$MISSING $f"; done
if [ "$TIER" = "1" ] && [ -f "$D/PLAN.md" ]; then MISSING="$(printf '%s' "$MISSING" | sed 's/ unit.md//')"; fi
O="$(run_hook aidlc-artifact-hygiene --all)"; R=$?
if [ -n "$MISSING" ]; then dim D2 "Artifact completeness & hygiene" FAIL "missing:$MISSING" "aidlc-delivery-manager"
elif [ $R -ne 0 ]; then dim D2 "Artifact completeness & hygiene" FAIL "$(printf '%s' "$O" | grep -Eo 'H0[0-9]: .*' | head -1)" "aidlc-delivery-manager"
else dim D2 "Artifact completeness & hygiene" PASS "required artifacts present ($(printf '%s' "$REQ" | wc -w | tr -d ' ')), hygiene clean" "aidlc-delivery-manager"; fi

# ---------------- D3 ----------------
PROF_NAME="$(jq -r --arg t "$TIER" '.tier_map[$t] // "standard"' "$GC")"
GATES="$(jq -r --arg p "$PROF_NAME" '.profiles[$p].hitl_gates[]? | select(. != "approve-release")' "$GC")"
HDF="$AIDLC_TRACK/human-decisions.md"
MISSING_G=""; ASSERTED=""
for g in $GATES; do
  REC="$(awk -v g="\`$g\`" -v p="\`$P\`" '/^### \[HD-/ {id=$2} index($0,"**Gate:** " g) && index($0,"**Phase:** " p) {print id " " $0}' "$HDF" 2>/dev/null \
        | grep -E 'Status:\*?\*? ?(APPROVED|APPROVED W/ RISK|BACKFILLED)' | tail -1)"
  if [ -z "$REC" ]; then MISSING_G="$MISSING_G $g"
  else
    hd="$(printf '%s' "$REC" | grep -Eo 'HD-[0-9]+' | head -1)"
    risk="$(printf '%s' "$REC" | sed -n 's/.*\*\*Risk:\*\* \([a-z-]*\).*/\1/p')"
    case "$risk" in high|security-sensitive|release)
      awk -v h="[$hd]" 'index($0,h){f=1} f && /identity: asserted/ {print "y"; exit} f && /^---$/ {exit}' "$HDF" | grep -q y && ASSERTED="$ASSERTED $hd" ;;
    esac
  fi
done
CO="$(run_hook aidlc-artifact-consistency-check --all)"; CR=$?
if [ -n "$MISSING_G" ]; then dim D3 "Human approval audit" FAIL "no accepted decision for:$MISSING_G" "aidlc-governance-reviewer (tech lead)"
elif [ $CR -ne 0 ]; then dim D3 "Human approval audit" FAIL "$(printf '%s' "$CO" | grep -Eo 'X0[0-9] .*' | head -1)" "aidlc-governance-reviewer (tech lead)"
else
  NOTE="gates:$(printf ' %s' $GATES) all decided; X00 consistent"
  [ -n "$ASSERTED" ] && NOTE="$NOTE; advisory: asserted identity at high/release risk on$ASSERTED (authoritative only through the decision bot, phase 4)"
  dim D3 "Human approval audit" PASS "$NOTE" "aidlc-governance-reviewer"
fi

# ---------------- D4 ----------------
V="$D/VERIFICATION.md"
if [ "$TIER" = "1" ]; then
  if [ -f "$D/evidence/index.json" ] && jq -e '.entries | length > 0' "$D/evidence/index.json" >/dev/null; then
    dim D4 "Evidence rail proof" PASS "tier 1: $(jq '.entries|length' "$D/evidence/index.json") recorded run(s)" "aidlc-verifier"
  else dim D4 "Evidence rail proof" FAIL "tier 1 still needs at least one recorded run" "aidlc-verifier (developer)"; fi
elif [ ! -f "$V" ]; then dim D4 "Evidence rail proof" FAIL "VERIFICATION.md missing" "aidlc-verifier (developer / QA)"
else
  SEAL="$(head -1 "$V" | sed -n 's/^<!-- generated-by: aidlc-evidence-verifier sha256:\([0-9a-f]\{64\}\) -->$/\1/p')"
  if [ -z "$SEAL" ] || [ "$SEAL" != "$(tail -n +2 "$V" | shasum -a 256 | cut -c1-64)" ]; then
    dim D4 "Evidence rail proof" FAIL "VERIFICATION.md is not sealed by the verifier" "aidlc-verifier (developer / QA)"
  elif ! grep -q '^## VERIFICATION COMPLETE' "$V"; then
    dim D4 "Evidence rail proof" FAIL "VERIFICATION.md is FAILED: $(grep -E '^\| [A-Z]+-?[0-9]* \|.*\| FAIL \|' "$V" | cut -d'|' -f2 | tr -d ' ' | tr '\n' ' ')" "aidlc-verifier (developer / QA)"
  elif [ -f "$D/evidence/index.json" ] && jq -e '[.entries | group_by(.command_hash)[] | max_by(.id) | select(.stale)] | length > 0' "$D/evidence/index.json" >/dev/null; then
    dim D4 "Evidence rail proof" FAIL "the latest run of a command is stale; re-record it and re-verify" "aidlc-verifier (developer / QA)"
  else dim D4 "Evidence rail proof" PASS "$(grep -m1 'Criteria:' "$V" | sed 's/.*Criteria:\*\* //')" "aidlc-verifier"; fi
fi

# ---------------- D5 ----------------
CONSUMES="$(grep -E '^consumes:' "$D/unit.yaml" 2>/dev/null | grep -Eo 'C-[0-9]+' | tr '\n' ' ')"
if [ "$TIER" != "3" ] || [ -z "$CONSUMES" ]; then dim D5 "Contract & workstream alignment" "N/A" "no consumed contracts" "aidlc-governance-reviewer"
else
  HUB="$(grep -E '^hub:' "$D/unit.yaml" | sed 's/^hub:[[:space:]]*//')"
  REGDIR="$AIDLC_TRACK"; [ -n "$HUB" ] && { case "$HUB" in /*) REGDIR="$HUB" ;; *) REGDIR="$AIDLC_PROJECT/$HUB" ;; esac; [ -d "$REGDIR/.track" ] && REGDIR="$REGDIR/.track"; }
  BAD=""; EXCL=""
  for c in $CONSUMES; do
    st="$(sed -n 's/^status:[[:space:]]*//p' "$REGDIR/contracts/$c.md" 2>/dev/null | head -1)"
    [ "$st" = "APPROVED" ] && continue
    if grep -E "APPROVE WORKSTREAM CONTRACT WITH RISK" "$REGDIR/human-decisions.md" 2>/dev/null | grep -q "$c"; then EXCL="$EXCL $c"; else BAD="$BAD $c(${st:-unregistered})"; fi
  done
  if [ -n "$BAD" ]; then dim D5 "Contract & workstream alignment" FAIL "consumed contracts not approved:$BAD" "aidlc-governance-reviewer (architect)"
  elif [ -n "$EXCL" ] || grep -q '^release_claims_excluded:[[:space:]]*true' "$D/unit.yaml"; then
    dim D5 "Contract & workstream alignment" FAIL "built on risk-accepted contracts:$EXCL; release claims are excluded until LIFT EXCLUSION" "aidlc-governance-reviewer (architect)"
  else dim D5 "Contract & workstream alignment" PASS "consumed contracts approved:$CONSUMES" "aidlc-governance-reviewer"; fi
fi

# ---------------- D6 ----------------
RV="$D/REVIEW.md"; RF="$AIDLC_TRACK/risks.md"
OPEN_FINDINGS=""; OPEN_RISKS=""
[ -f "$RV" ] && OPEN_FINDINGS="$(grep -Ei '(CRITICAL|HIGH)' "$RV" | grep -Eic '(\|[[:space:]]*open[[:space:]]*\||status:[[:space:]]*open)')"
[ -f "$RF" ] && OPEN_RISKS="$(grep -E '^\| RISK-[0-9]+' "$RF" | awk -F'|' '{st=$5; so=$6; gsub(/ /,"",st); gsub(/ /,"",so); if (tolower(st)=="open" && so !~ /HD-[0-9]+/) print $2}' | tr -d ' ' | tr '\n' ' ')"
if [ "$TIER" != "1" ] && [ ! -f "$RV" ]; then dim D6 "Security, NFR & risk" FAIL "REVIEW.md missing" "aidlc-security-standards-reviewer"
elif [ "${OPEN_FINDINGS:-0}" -gt 0 ] 2>/dev/null; then dim D6 "Security, NFR & risk" FAIL "$OPEN_FINDINGS open CRITICAL/HIGH finding(s) in REVIEW.md" "aidlc-security-standards-reviewer"
elif [ -n "$OPEN_RISKS" ]; then dim D6 "Security, NFR & risk" FAIL "open risks without a signing decision: $OPEN_RISKS" "aidlc-security-standards-reviewer"
else dim D6 "Security, NFR & risk" PASS "no open CRITICAL/HIGH findings; every open risk signed" "aidlc-security-standards-reviewer"; fi

# ---------------- write ----------------
if [ $FAILED -eq 0 ]; then RESULT="APPROVED"; else RESULT="BLOCKED"; fi
OUT="$D/SCORECARD.md"; BODY="$(mktemp)"
{
  echo "# Governance scorecard — $P"
  echo ""
  echo "## Summary"
  echo "- **Result:** GOVERNANCE $RESULT"
  echo "- **Dimensions failed:** $FAILED${FAILED_DIMS:+ ($FAILED_DIMS )}"
  echo "- **Tier:** $TIER · **Profile:** ${PROFILE:-none} · **Gate profile:** $PROF_NAME · **Generated:** $(aidlc_now)"
  echo "- **Inputs:** VERIFICATION.md sha256:$(aidlc_hash "$V") · human-decisions.md sha256:$(aidlc_hash "$HDF")"
  echo ""
  echo "## Dimensions"
  echo ""
  echo "| # | Dimension | Result | Detail | Owner |"
  echo "| --- | --- | --- | --- | --- |"
  printf '%s' "$ROWS"
  echo ""
  if [ "$RESULT" = "APPROVED" ]; then
    echo "Release proceeds to the APPROVE RELEASE gate with this scorecard attached to the decision record."
  else
    echo "Release is blocked. Each failed dimension names the owner who clears it; re-run the scorecard afterwards."
  fi
  echo ""
  echo "## GOVERNANCE $RESULT"
} > "$BODY"
SEAL="$(shasum -a 256 "$BODY" | cut -c1-64)"
{ echo "<!-- generated-by: aidlc-scorecard sha256:$SEAL -->"; cat "$BODY"; } > "$OUT"
rm -f "$BODY"

GH="$AIDLC_TRACK/gate-history.json"
[ -f "$GH" ] || echo '{"gates":[]}' > "$GH"
DIMS_JSON="$(printf '%s' "$ROWS" | awk -F'|' 'NF>5 {gsub(/^ +| +$/,"",$2); gsub(/^ +| +$/,"",$4); print $2"\t"$4}' | jq -R 'split("\t") | {(.[0]): .[1]}' | jq -s 'add')"
TMP="$(mktemp)"
jq --arg p "$P" --arg d "$(aidlc_now)" --arg r "$RESULT" --argjson dims "$DIMS_JSON" --arg seal "$SEAL" \
  '.gates += [{type:"release-scorecard", phase:$p, date:$d, decision:(if $r=="APPROVED" then "PASS" else "FAIL" end), dimensions:$dims, seal:$seal}]' "$GH" > "$TMP" && cat "$TMP" > "$GH"
rm -f "$TMP"
aidlc_lineage "-" "decision.scorecard: GOVERNANCE_$RESULT" "$(aidlc_rel "$OUT")" "$(aidlc_hash "$OUT")"

sed -n '/## Summary/,/## Dimensions/p' "$OUT" | sed '$d'
printf '%s' "$ROWS"
echo "## GOVERNANCE $RESULT"
[ "$RESULT" = "APPROVED" ] && exit 0 || exit 2
