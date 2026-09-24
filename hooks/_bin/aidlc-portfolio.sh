#!/bin/bash
# ------------------------------------------------------------------
# aidlc-portfolio — the data the read-only console renders.
# ------------------------------------------------------------------
# Usage:
#   aidlc-portfolio.sh [--out docs/aidlc/console-data] [--repo <name>]
#   aidlc-portfolio.sh --merge <out-dir> <console-data-dir> [<console-data-dir> ...]   (department job)
# Writes portfolio.json, checkpoints.json, decisions.json, guardrails.json, and copies
# metrics.json and index.json when present. Git stays the only database: every value
# here is read from the track root and can be traced to a file.
# ------------------------------------------------------------------
AIDLC_HOOK_NAME="aidlc-portfolio"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
aidlc_require_jq
AIDLC_INPUT='{}'

if [ "$1" = "--merge" ]; then
  OUT="$2"; shift 2; mkdir -p "$OUT"
  for f in portfolio checkpoints decisions guardrails; do
    for d in "$@"; do [ -f "$d/$f.json" ] && cat "$d/$f.json"; done | jq -s --arg f "$f" \
      'if $f=="portfolio" then {as_of:(now|todate), repos:map(.repos[]?)} else {as_of:(now|todate), items:map(.items[]?)} end' > "$OUT/$f.json"
  done
  for d in "$@"; do [ -f "$d/metrics.json" ] && cat "$d/metrics.json"; done | jq -s '{as_of:(now|todate), squads:.}' > "$OUT/metrics.json"
  for d in "$@"; do [ -f "$d/index.json" ] && cat "$d/index.json"; done | jq -s '{as_of:(now|todate), pages:map(.pages[]?), phases:map(.phases[]?), decisions:map(.decisions[]?)}' > "$OUT/index.json"
  echo "P00 merged $# repo(s) into $OUT"; exit 0
fi

OUT=""; REPO=""
while [ $# -gt 0 ]; do case "$1" in --out) OUT="$2"; shift 2 ;; --repo) REPO="$2"; shift 2 ;; *) shift ;; esac; done
aidlc_load_state
aidlc_active || { echo "aidlc-portfolio: no track root" >&2; exit 1; }
[ -z "$OUT" ] && OUT="$AIDLC_PROJECT/docs/aidlc/console-data"
case "$OUT" in /*) ;; *) OUT="$AIDLC_PROJECT/$OUT" ;; esac
mkdir -p "$OUT"
[ -z "$REPO" ] && REPO="$(basename "$AIDLC_PROJECT")"
S="$AIDLC_STATE"; rf() { resume_field "$S" "$1"; }

PHASES="$(awk '/^## Phases/ {f=1; next} f && /^## / {exit} f && /^\| [0-9]/' "$S" \
  | awk -F'|' '{for(i=2;i<=7;i++) gsub(/^ +| +$/,"",$i); printf "%s\t%s\t%s\t%s\t%s\t%s\n",$2,$3,$4,$5,$6,$7}' \
  | jq -R 'split("\t") | {phase:.[0], stage:.[1], tier:(.[2]|tonumber? // null), profile:.[3], risk:.[4], last_decision:.[5]}' | jq -sc .)"
PHASES="$(printf '%s' "$PHASES" | jq -c --arg t "$AIDLC_TRACK" 'map(.)')"
# enrich with verification and scorecard results
EN='[]'
for row in $(printf '%s' "$PHASES" | jq -r '.[] | @base64'); do
  r="$(printf '%s' "$row" | base64 --decode)"; p="$(printf '%s' "$r" | jq -r .phase)"; d="$AIDLC_TRACK/phases/$p"
  v="$(grep -m1 'Result:' "$d/VERIFICATION.md" 2>/dev/null | sed 's/.*Result:\*\* //')"
  sc="$(grep -m1 'Result:' "$d/SCORECARD.md" 2>/dev/null | sed 's/.*Result:\*\* //')"
  EN="$(printf '%s' "$EN" | jq -c --argjson r "$r" --arg v "${v:-none}" --arg sc "${sc:-none}" '. + [$r + {verification:$v, scorecard:$sc}]')"
done
CONTRACTS="$(awk -F'|' '/^\| C-[0-9]+/ {for(i=2;i<=8;i++) gsub(/^ +| +$/,"",$i); printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n",$2,$3,$4,$5,$6,$7,$8}' "$AIDLC_TRACK/contract-registry.md" 2>/dev/null \
  | jq -R 'split("\t") | {id:.[0], kind:.[1], producer:.[2], consumers:.[3], version:.[4], status:.[5], approved_by:.[6]}' | jq -sc .)"
jq -n --arg repo "$REPO" --arg asof "$(aidlc_now)" --arg ph "$(rf CURRENT_PHASE)" --arg st "$(rf CURRENT_STAGE)" --arg g "$(rf BLOCKED_GATE)" \
  --arg risk "$(rf GATE_RISK)" --arg na "$(rf NEXT_ACTION)" --arg owner "$(rf NEXT_ACTION_OWNER)" --argjson phases "$EN" --argjson contracts "${CONTRACTS:-[]}" \
  '{as_of:$asof, repos:[{repo:$repo, resume:{phase:$ph, stage:$st, blocked_gate:$g, gate_risk:$risk, next_action:$na, owner:$owner}, phases:$phases, contracts:$contracts}]}' > "$OUT/portfolio.json"

ITEMS='[]'
if [ "$(rf BLOCKED_GATE)" != "none" ] && [ -n "$(rf BLOCKED_GATE)" ]; then
  G="$(rf BLOCKED_GATE)"
  PUB="$(grep -F "decision.checkpoint_published: $G" "$AIDLC_TRACK/lineage.md" 2>/dev/null | tail -1 | cut -d' ' -f1)"
  SLA="$(grep -E "^  $G:" "$AIDLC_TRACK/stakeholders.yaml" 2>/dev/null | grep -Eo 'sla_hours: *[0-9]+' | grep -Eo '[0-9]+')"
  DECIDER="$(grep -E "^  $G:" "$AIDLC_TRACK/stakeholders.yaml" 2>/dev/null | sed -n 's/.*decider: *\([a-z-]*\).*/\1/p')"
  INPUTS='[]'; OLDIFS="$IFS"; IFS=','
  for a in $(rf NEXT_ACTION_INPUTS); do a="$(printf '%s' "$a" | sed 's/^ *//; s/ *$//')"; [ -z "$a" ] || [ "$a" = none ] && continue
    INPUTS="$(printf '%s' "$INPUTS" | jq -c --arg p "$a" --arg h "$(aidlc_hash "$(aidlc_abs "$a")")" '. + [{path:$p, sha256:$h}]')"; done; IFS="$OLDIFS"
  ITEMS="$(jq -nc --arg repo "$REPO" --arg g "$G" --arg risk "$(rf GATE_RISK)" --arg ph "$(rf CURRENT_PHASE)" --arg pub "$PUB" \
    --arg sla "${SLA:-48}" --arg decider "${DECIDER:-unspecified}" --argjson inputs "$INPUTS" --arg na "$(rf NEXT_ACTION)" \
    '[{repo:$repo, gate:$g, risk:$risk, phase:$ph, published_at:(if $pub=="" then null else $pub end), sla_hours:($sla|tonumber), decider:$decider, inputs:$inputs, next_action:$na}]')"
fi
jq -n --arg asof "$(aidlc_now)" --argjson items "$ITEMS" '{as_of:$asof, items:$items}' > "$OUT/checkpoints.json"

HDF="$AIDLC_TRACK/human-decisions.md"
DEC="$(awk '/^### \[HD-/ {id=$2; gsub(/[\[\]]/,"",id); t=$0; sub(/^### \[[^]]*\] /,"",t)}
  /\*\*Timestamp:\*\*/ {ts=$0; sub(/.*\*\*Timestamp:\*\* /,"",ts)}
  /\*\*Decider:\*\*/ {who=$0; sub(/.*\*\*Decider:\*\* /,"",who)}
  /\*\*Gate:\*\*/ && id!="" {g=$0; sub(/.*\*\*Gate:\*\* `/,"",g); sub(/`.*/,"",g); r=$0; sub(/.*\*\*Risk:\*\* /,"",r); sub(/ .*/,"",r); p=$0; sub(/.*\*\*Phase:\*\* `/,"",p); sub(/`.*/,"",p); st=$0; sub(/.*\*\*Status:\*\* /,"",st); printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, ts, who, g, r, p, st, t; id=""}' "$HDF" 2>/dev/null \
  | jq -R --arg repo "$REPO" 'split("\t") | {repo:$repo, id:.[0], at:.[1], decider:.[2], gate:.[3], risk:.[4], phase:.[5], status:.[6], decision:.[7], identity:(if (.[2]|test("identity: sso")) then "sso" else "asserted" end)}' | jq -sc .)"
BLK="$(grep -E '^\* \*\*Attempt on' "$HDF" 2>/dev/null | sed -E 's/^\* \*\*Attempt on ([^ ]+) \(([^ ]*) - gate ([^,]*), risk ([^)]*)\)\*\*:$/\1\t\2\t\3\t\4/' \
  | jq -R --arg repo "$REPO" 'split("\t") | {repo:$repo, at:.[0], role:.[1], gate:.[2], risk:.[3], status:"REJECTED (vague)"}' | jq -sc .)"
jq -n --arg asof "$(aidlc_now)" --argjson d "${DEC:-[]}" --argjson b "${BLK:-[]}" '{as_of:$asof, items:($d + $b)}' > "$OUT/decisions.json"

GL="$AIDLC_TRACK/guardrail-log.md"
GR="$(grep -E '^\| [0-9]{4}-' "$GL" 2>/dev/null | awk -F'|' '{for(i=2;i<=6;i++) gsub(/^ +| +$/,"",$i); printf "%s\t%s\t%s\t%s\t%s\n",$2,$3,$4,$5,$6}' \
  | jq -R --arg repo "$REPO" 'split("\t") | {repo:$repo, at:.[0], hook:.[1], code:.[2], phase:.[3], detail:.[4]}' | jq -sc .)"
jq -n --arg asof "$(aidlc_now)" --argjson g "${GR:-[]}" '{as_of:$asof, items:$g}' > "$OUT/guardrails.json"

[ -f "$AIDLC_PROJECT/docs/aidlc/metrics/metrics.json" ] && cp "$AIDLC_PROJECT/docs/aidlc/metrics/metrics.json" "$OUT/metrics.json"
[ -f "$AIDLC_PROJECT/docs/aidlc/index.json" ] && cp "$AIDLC_PROJECT/docs/aidlc/index.json" "$OUT/index.json"
echo "P00 console data for $REPO → $(aidlc_rel "$OUT") ($(jq '.repos[0].phases|length' "$OUT/portfolio.json") phase(s), $(jq '.items|length' "$OUT/checkpoints.json") open checkpoint(s), $(jq '.items|length' "$OUT/decisions.json") decision(s))"
