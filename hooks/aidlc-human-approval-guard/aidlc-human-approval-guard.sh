#!/bin/bash
# aidlc-human-approval-guard — runs on every user prompt while a gate is open.
#
# A structured decision string for the open gate is recorded: HD record, lineage
# line, risk entry when a risk is accepted, and a state.md update. A decision
# receipt is printed on stdout (added to the agent's context).
# A vague approval ("ok", "looks good") is rejected with code A01 above low risk
# and logged in section 4 of human-decisions.md. At low risk it is normalised.
# Anything else (a question, a discussion) passes through untouched.
#
# Direct use (agents without prompt hooks, the decision bot):
#   echo '{"prompt":"APPROVE PLAN"}' | aidlc-human-approval-guard.sh [--as <name>] [--role <role>] [--identity sso]
AIDLC_HOOK_NAME="aidlc-human-approval-guard"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
aidlc_require_jq

DECIDER="${AIDLC_DECIDER:-}"; ROLE="${AIDLC_DECIDER_ROLE:-}"; IDSRC="${AIDLC_IDENTITY_SOURCE:-asserted}"
while [ $# -gt 0 ]; do
  case "$1" in
    --as) DECIDER="$2"; shift 2 ;;
    --role) ROLE="$2"; shift 2 ;;
    --identity) IDSRC="$2"; shift 2 ;;
    *) shift ;;
  esac
done

aidlc_read_input
aidlc_load_state
aidlc_active || exit 0
[ "$AIDLC_GATE" = "none" ] && exit 0

PROMPT="$(aidlc_field .prompt)"
LINE="$(printf '%s\n' "$PROMPT" | sed '/^[[:space:]]*$/d' | head -1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
[ -z "$LINE" ] && exit 0

GATE="$AIDLC_GATE"
RISK="$AIDLC_GATE_RISK"
if [ -z "$RISK" ] || [ "$RISK" = "none" ]; then
  # Fall back to gate-config: risk_levels[gate][profile of this tier].
  TIER="$(aidlc_tier)"
  AGENT_DIR="$(aidlc_agent_dir_name "$AIDLC_PROJECT")"
  GC="$AIDLC_PROJECT/$AGENT_DIR/config/gate-config.json"
  if [ -f "$GC" ]; then
    RISK="$(jq -r --arg g "$GATE" --arg t "$TIER" '(.tier_map[$t] // "standard") as $p | .risk_levels[$g][$p] // empty' "$GC")"
  fi
  [ -z "$RISK" ] && RISK="medium"
fi

# Security escalation: an open security finding makes every gate security-sensitive.
if [ "$RISK" != "release" ] && [ -f "$AIDLC_TRACK/risks.md" ] \
   && grep -Ei '^\|[^|]*RISK-[0-9]+' "$AIDLC_TRACK/risks.md" | grep -Ei 'security' | grep -Eiq '\|[[:space:]]*open[[:space:]]*\|'; then
  RISK="security-sensitive"
fi

UGATE="$(printf '%s' "$GATE" | sed 's/^approve-//; s/-/ /g' | tr '[:lower:]' '[:upper:]')"
case "$GATE" in
  approve-*) GATE_TOKEN="APPROVE $UGATE" ;;
  lift-exclusion) GATE_TOKEN="LIFT EXCLUSION" ;;
  *) GATE_TOKEN="APPROVE $UGATE" ;;
esac
[ "$GATE" = "approve-contract" ] && GATE_TOKEN="APPROVE WORKSTREAM CONTRACT"
IS_RELEASE=0; case "$GATE" in *release*) IS_RELEASE=1 ;; esac

accepted_list() {
  local a="$GATE_TOKEN"
  case "$GATE" in
    approve-contract) a="APPROVE WORKSTREAM CONTRACT: WS-NNN | APPROVE WORKSTREAM CONTRACT WITH RISK: WS-NNN - <risk and excluded scope>" ;;
    approve-workstream-plan) a="APPROVE WORKSTREAM PLAN: WS-NNN" ;;
    lift-exclusion) a="LIFT EXCLUSION: WS-NNN" ;;
  esac
  case "$RISK" in high|security-sensitive) a="$a: <risk acknowledgement>" ;; release) a="$a: <release scope>" ;; esac
  a="$a | APPROVE WITH RISK: <risk and excluded scope> | REQUEST CHANGES: <reason> | REQUEST VERIFICATION: <missing evidence>"
  if [ $IS_RELEASE -eq 1 ]; then a="$a | DEFER RELEASE | REJECT RELEASE"; else a="$a | DEFER"; fi
  echo "$a"
}

log_blocked() {
  local code="$1" reason="$2" hd="$AIDLC_TRACK/human-decisions.md"
  [ -f "$hd" ] || return 0
  printf '* **Attempt on %s (%s - gate %s, risk %s)**:\n  - Input: *"%s"*\n  - Result: **REJECTED (Code 403 - %s)**\n  - Reason: %s\n' \
    "$(aidlc_now)" "${ROLE:-unspecified}" "$GATE" "$RISK" "$(printf '%s' "$LINE" | cut -c1-120 | tr '"' "'")" "$code" "$reason" >> "$hd"
}

reject() {
  local code="$1" reason="$2"
  log_blocked "$code" "$reason"
  aidlc_lineage "-" "decision.rejected_vague: $GATE ($code)" "-" "-"
  aidlc_block "$code" "$reason (gate $GATE, risk $RISK)" "reply with one of: $(accepted_list)"
}

# ---------- classify the reply ----------
STATUS=""; TEXT=""; DECISION="$LINE"; NORMALISED_FROM=""
after_colon() { printf '%s' "$1" | sed 's/^[^:]*:[[:space:]]*//'; }

case "$LINE" in
  "APPROVE WITH RISK:"*|"APPROVE WORKSTREAM CONTRACT WITH RISK:"*)
    TEXT="$(after_colon "$LINE")"
    case "$LINE" in "APPROVE WORKSTREAM CONTRACT WITH RISK:"*)
      [ "$GATE" = "approve-contract" ] || reject A02 "contract decision given at gate $GATE"
      printf '%s' "$TEXT" | grep -Eq '^WS-[0-9]+' || reject A03 "workstream id missing"
      TEXT="$(printf '%s' "$TEXT" | sed -E 's/^WS-[0-9]+[[:space:]]*-?[[:space:]]*//')" ;;
    esac
    [ ${#TEXT} -lt 10 ] && reject A03 "risk acknowledgement missing or too short"
    STATUS="APPROVED W/ RISK" ;;
  "REQUEST CHANGES:"*)
    TEXT="$(after_colon "$LINE")"; [ ${#TEXT} -lt 5 ] && reject A03 "reason missing"; STATUS="CHANGES REQUESTED" ;;
  "REQUEST VERIFICATION:"*)
    TEXT="$(after_colon "$LINE")"; [ ${#TEXT} -lt 5 ] && reject A03 "missing evidence not named"; STATUS="VERIFICATION REQUESTED" ;;
  "DEFER RELEASE"*|"REJECT RELEASE"*)
    [ $IS_RELEASE -eq 1 ] || reject A02 "release decision given at non-release gate $GATE"
    case "$LINE" in "DEFER"*) STATUS="DEFERRED" ;; *) STATUS="REJECTED" ;; esac
    TEXT="$(printf '%s' "$LINE" | sed -n 's/^[A-Z ]*:[[:space:]]*//p')" ;;
  "DEFER"|"DEFER:"*)
    [ $IS_RELEASE -eq 1 ] && reject A02 "use DEFER RELEASE at a release gate"
    STATUS="DEFERRED"; TEXT="$(printf '%s' "$LINE" | sed -n 's/^DEFER:[[:space:]]*//p')" ;;
  APPROVE*|LIFT*)
    case "$LINE" in
      "$GATE_TOKEN"|"$GATE_TOKEN:"*|"$GATE_TOKEN "*) ;;
      *) reject A02 "decision does not name the open gate" ;;
    esac
    REST="${LINE#$GATE_TOKEN}"
    case "$GATE" in
      approve-contract|approve-workstream-plan|lift-exclusion)
        printf '%s' "$REST" | grep -Eq '^:?[[:space:]]*WS-[0-9]+' || reject A03 "workstream id missing" ;;
    esac
    TEXT="$(printf '%s' "$REST" | sed -E 's/^:?[[:space:]]*(WS-[0-9]+)?[[:space:]]*[-:]?[[:space:]]*//')"
    case "$RISK" in
      high|security-sensitive) [ ${#TEXT} -lt 10 ] && reject A03 "risk acknowledgement required at $RISK risk" ;;
      release) [ ${#TEXT} -lt 10 ] && reject A03 "release scope required at a release gate" ;;
    esac
    STATUS="APPROVED"
    [ "$GATE" = "lift-exclusion" ] && STATUS="APPROVED" ;;
  *)
    # Vague approval lexicon: the whole reply is affirmative filler.
    NORM="$(printf '%s' "$LINE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z ]+/ /g; s/[[:space:]]+/ /g; s/^ //; s/ $//')"
    VAGUE='^((ok|okay|k|yes|yep|yeah|yup|sure|fine|approve|approved|lgtm|continue|proceed|go|go ahead|ship|ship it|sounds good|looks good|looks good to me|good|great|perfect|done|agreed|do it|lets go|let s go|go for it|thumbs up|all good|that s fine|thats fine|works for me|looks fine|approve it|approve this|ok go|yes please|yes go ahead)( |$))+$'
    if [ -z "$NORM" ] || printf '%s' "$NORM" | grep -Eq "$VAGUE"; then
      if [ "$RISK" = "low" ]; then
        NORMALISED_FROM="$LINE"; DECISION="$GATE_TOKEN"; STATUS="APPROVED"
      else
        reject A01 "vague approval"
      fi
    else
      UP="$(printf '%s' "$LINE" | tr '[:lower:]' '[:upper:]')"
      case "$UP" in
        APPROVE\ *|REQUEST\ *|DEFER|DEFER\ *|DEFER:*|REJECT\ *|LIFT\ *)
          reject A04 "decision strings are upper case and exact (\"$UP\" would be read as a decision)" ;;
      esac
      echo "AIDLC: gate $GATE is open ($RISK risk). No decision was recorded from this message. Decide with: $(accepted_list)"
      exit 0
    fi ;;
esac

# ---------- record the decision ----------
HDF="$AIDLC_TRACK/human-decisions.md"
if [ ! -f "$HDF" ]; then
  TPL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/templates/track/human-decisions.md"
  if [ -f "$TPL" ]; then cp "$TPL" "$HDF"; else printf '# AIDLC Human Decisions Log\n\n## 2. Decision Log Index\n\n| Decision ID | Date/Time (UTC) | Deciding Role | Decision / Gate Action | Status | Summary |\n| :--- | :--- | :--- | :--- | :--- | :--- |\n\n---\n\n## 3. Detailed Decision Records\n\n---\n\n## 4. Blocked Vague Approval Log (Auditable Block/Failure Attempts)\n\n' > "$HDF"; fi
fi

N="$(grep -Eo '^### \[HD-[0-9]+\]' "$HDF" | sed -E 's/[^0-9]//g' | sort -n | tail -1)"
N=$(( 10#${N:-0} + 1 ))
HD="$(printf 'HD-%03d' "$N")"
TS="$(aidlc_now)"
[ -z "$DECIDER" ] && DECIDER="$(git -C "$AIDLC_PROJECT" config user.name 2>/dev/null)"
[ -z "$DECIDER" ] && DECIDER="${USER:-unknown}"
[ -z "$ROLE" ] && ROLE="unspecified"

# Artifacts under review: NEXT_ACTION_INPUTS from the resume block.
INPUTS="$(resume_field "$AIDLC_STATE" NEXT_ACTION_INPUTS)"
ART_LINES=""; FIRST_ART="-"; FIRST_HASH="-"
OLDIFS="$IFS"; IFS=','
for a in $INPUTS; do
  a="$(printf '%s' "$a" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -z "$a" ] || [ "$a" = "none" ] && continue
  ab="$(aidlc_abs "$a")"; [ -f "$ab" ] || ab="$AIDLC_PHASE_DIR/$a"
  h="$(aidlc_hash "$ab")"
  ART_LINES="$ART_LINES  - \`$(aidlc_rel "$ab")\` sha256:$h
"
  [ "$FIRST_ART" = "-" ] && { FIRST_ART="$(aidlc_rel "$ab")"; FIRST_HASH="$h"; }
done
IFS="$OLDIFS"
[ -z "$ART_LINES" ] && ART_LINES="  - none listed
"

EVENT="decision.accepted"
case "$STATUS" in
  "CHANGES REQUESTED") EVENT="decision.request_changes" ;;
  "VERIFICATION REQUESTED") EVENT="decision.request_verification" ;;
  "DEFERRED") EVENT="decision.deferred" ;;
  "REJECTED") EVENT="decision.rejected" ;;
esac
[ "$GATE" = "lift-exclusion" ] && [ "$STATUS" = "APPROVED" ] && EVENT="decision.lifted_exclusion"

RISK_ID=""
if [ "$STATUS" = "APPROVED W/ RISK" ]; then
  RF="$AIDLC_TRACK/risks.md"
  [ -f "$RF" ] || printf '# Risk register\n\n| ID | Risk | Raised by | Status | signed_off_by |\n| --- | --- | --- | --- | --- |\n' > "$RF"
  RN="$(grep -Eo 'RISK-[0-9]+' "$RF" | sed 's/RISK-//' | sort -n | tail -1)"
  RN=$(( 10#${RN:-0} + 1 )); RISK_ID="$(printf 'RISK-%03d' "$RN")"
  printf '| %s | %s | %s at %s | accepted | %s |\n' "$RISK_ID" "$(printf '%s' "$TEXT" | tr '|' '/')" "$ROLE" "$GATE" "$HD" >> "$RF"
fi

SUMMARY="$(printf '%s' "${TEXT:-$DECISION}" | tr '|' '/' | cut -c1-90)"
INDEX_ROW="| **$HD** | ${TS%:*} | $ROLE | \`$(printf '%s' "$DECISION" | cut -c1-80 | tr '|' '/')\` | **$STATUS** | $SUMMARY |"

RECORD="### [$HD] $(printf '%s' "$DECISION" | cut -c1-80)
- **Timestamp:** $TS
- **Decider:** $DECIDER ($ROLE), identity: $IDSRC
- **Gate:** \`$GATE\` · **Risk:** $RISK · **Phase:** \`$AIDLC_PHASE\` · **Status:** $STATUS
- **Decision String:**
  \`\`\`text
  $DECISION
  \`\`\`"
[ -n "$NORMALISED_FROM" ] && RECORD="$RECORD
- **Normalised from:** \"$NORMALISED_FROM\" (casual approval allowed at low risk)"
[ -n "$RISK_ID" ] && RECORD="$RECORD
- **Accepted Risk:** \`$RISK_ID\` in \`risks.md\`"
RECORD="$RECORD
- **Artifacts Approved:**
$ART_LINES- **Lineage Event:** \`$EVENT: $GATE\`

---
"

TMP="$(mktemp)"
AIDLC_ROW="$INDEX_ROW" AIDLC_REC="$RECORD" awk '
  BEGIN { row=ENVIRON["AIDLC_ROW"]; rec=ENVIRON["AIDLC_REC"] }
  { lines[NR]=$0 }
  /^## 2\./ {s2=NR} /^## 3\./ {s3=NR} /^## 4\./ {s4=NR}
  END {
    last=0
    for (i=s2; i<s3 && s2>0; i++) if (lines[i] ~ /^\|/) last=i
    for (i=1; i<=NR; i++) {
      if (i==s4 && s4>0) { print rec }
      print lines[i]
      if (i==last) print row
    }
    if (s4==0) print rec
  }' "$HDF" > "$TMP" && cat "$TMP" > "$HDF"
rm -f "$TMP"

aidlc_lineage "$HD" "$EVENT: $GATE" "$FIRST_ART" "$FIRST_HASH"
[ -n "$RISK_ID" ] && aidlc_lineage "$HD" "decision.approved_with_risk: $RISK_ID" "$(aidlc_rel "$AIDLC_TRACK/risks.md")" "-"

# ---------- update the resume block ----------
case "$STATUS" in
  "APPROVED"|"APPROVED W/ RISK")
    set_resume_field "$AIDLC_STATE" BLOCKED_GATE none
    set_resume_field "$AIDLC_STATE" GATE_RISK none
    set_resume_field "$AIDLC_STATE" NEXT_ACTION "Resume the pipeline with /run-pipeline --resume ($HD recorded for $GATE)"
    set_resume_field "$AIDLC_STATE" NEXT_ACTION_OWNER "agent:aidlc-orchestrator" ;;
  "CHANGES REQUESTED"|"VERIFICATION REQUESTED")
    set_resume_field "$AIDLC_STATE" BLOCKED_GATE none
    set_resume_field "$AIDLC_STATE" GATE_RISK none
    set_resume_field "$AIDLC_STATE" NEXT_ACTION "Address $HD ($STATUS at $GATE): $(printf '%s' "$TEXT" | cut -c1-120), then republish the checkpoint"
    set_resume_field "$AIDLC_STATE" NEXT_ACTION_OWNER "agent:aidlc-orchestrator" ;;
  "DEFERRED")
    set_resume_field "$AIDLC_STATE" NEXT_ACTION "Gate $GATE deferred by $HD; decide later with: $(accepted_list | cut -d'|' -f1)"
    set_resume_field "$AIDLC_STATE" NEXT_ACTION_OWNER "human:$ROLE" ;;
  "REJECTED")
    set_resume_field "$AIDLC_STATE" BLOCKED_GATE none
    set_resume_field "$AIDLC_STATE" GATE_RISK none
    set_resume_field "$AIDLC_STATE" NEXT_ACTION "Release rejected by $HD; the phase stays unreleased"
    set_resume_field "$AIDLC_STATE" NEXT_ACTION_OWNER "human:$ROLE" ;;
esac

cat <<EOF
DECISION RECEIPT $HD
Gate: $GATE  Risk: $RISK  Phase: $AIDLC_PHASE
Decision: $DECISION
Status: $STATUS
Decider: $DECIDER ($ROLE), identity $IDSRC
Artifacts: $(printf '%s' "$ART_LINES" | tr -d '\n' | sed 's/^  - //; s/  - /; /g')
${RISK_ID:+Risk: $RISK_ID appended to risks.md
}Lineage: $EVENT: $GATE
State: $( [ "$STATUS" = "DEFERRED" ] && echo "gate stays open" || echo "BLOCKED_GATE cleared, NEXT_ACTION set" )
EOF
exit 0
