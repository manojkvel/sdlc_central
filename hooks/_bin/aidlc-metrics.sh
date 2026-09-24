#!/bin/bash
# ------------------------------------------------------------------
# aidlc-metrics — AIDLC-native metrics, computed only from the track root.
# ------------------------------------------------------------------
# Usage: aidlc-metrics.sh [--out docs/aidlc/metrics] [--squad <name>]
# Writes <out>/metrics.json, phases.csv, decisions.csv, guardrails.csv.
# Every rate carries its numerator and denominator; a metric whose source does not
# exist is null, never zero. Nothing is self-reported. No model calls.
# Sources: lineage.md, human-decisions.md, VERIFICATION.md, guardrail-log.md,
#          gate-history.json, runs/*.json (usage), incidents.json (optional, from incident-triager),
#          baseline.json (optional, the squad's pre-AIDLC baseline).
# ------------------------------------------------------------------
AIDLC_HOOK_NAME="aidlc-metrics"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
aidlc_require_jq
AIDLC_INPUT='{}'
OUTDIR=""; SQUAD=""
while [ $# -gt 0 ]; do case "$1" in --out) OUTDIR="$2"; shift 2 ;; --squad) SQUAD="$2"; shift 2 ;; *) shift ;; esac; done
aidlc_load_state
aidlc_active || { echo "aidlc-metrics: no track root" >&2; exit 1; }
[ -z "$OUTDIR" ] && OUTDIR="$AIDLC_PROJECT/docs/aidlc/metrics"
case "$OUTDIR" in /*) ;; *) OUTDIR="$AIDLC_PROJECT/$OUTDIR" ;; esac
mkdir -p "$OUTDIR"
[ -z "$SQUAD" ] && SQUAD="$(basename "$AIDLC_PROJECT")"
LIN="$AIDLC_TRACK/lineage.md"; HDF="$AIDLC_TRACK/human-decisions.md"; GL="$AIDLC_TRACK/guardrail-log.md"; GH="$AIDLC_TRACK/gate-history.json"

epoch() { date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null || date -u -d "$1" +%s 2>/dev/null; }

# lineage as TSV: ts \t ref \t event \t artifact
LTSV="$(mktemp)"
grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$LIN" 2>/dev/null | awk -F' \\| ' '{print $1"\t"$2"\t"$3"\t"$4}' > "$LTSV"

PHASES_JSON='[]'
for d in "$AIDLC_TRACK"/phases/*/; do
  [ -d "$d" ] || continue
  p="$(basename "$d")"
  tier="$(grep -E '^tier:' "$d/unit.yaml" 2>/dev/null | sed 's/[^0-9]//g')"
  profile="$(grep -E '^profile:' "$d/unit.yaml" 2>/dev/null | sed 's/^profile:[[:space:]]*//')"
  # events that belong to this phase: the artifact path names the phase directory
  PEV="$(awk -F'\t' -v p="/phases/$p/" 'index($4,p)' "$LTSV")"
  first="$(printf '%s\n' "$PEV" | head -1 | cut -f1)"
  released="$(printf '%s\n' "$PEV" | grep -F 'stage.entered: released' | head -1 | cut -f1)"
  lead="null"
  if [ -n "$first" ] && [ -n "$released" ]; then lead="$(echo "scale=2; ($(epoch "$released") - $(epoch "$first")) / 86400" | bc)"; fi
  # stage residency (days) from consecutive stage.entered events
  STAGES="$(printf '%s\n' "$PEV" | grep -F 'stage.entered: ' | while IFS="$(printf '\t')" read -r ts ref ev art; do echo "$(epoch "$ts") ${ev#stage.entered: }"; done \
    | awk 'NR>1 {d[s]+=($1-t)/86400} {t=$1; s=$2} END {printf "{"; n=0; for (k in d) {printf "%s\"%s\":%.2f", (n++?",":""), k, d[k]}; printf "}"}')"
  [ -z "$STAGES" ] && STAGES='{}'
  # decisions for this phase
  hd_total="$(grep -c "\*\*Phase:\*\* \`$p\`" "$HDF" 2>/dev/null)"; hd_total=${hd_total:-0}
  hd_rework="$(grep "\*\*Phase:\*\* \`$p\`" "$HDF" 2>/dev/null | grep -Ec 'CHANGES REQUESTED|VERIFICATION REQUESTED')"; hd_rework=${hd_rework:-0}
  # evidence coverage from the sealed verification
  vpass="null"; vtotal="null"; vresult="null"
  if [ -f "$d/VERIFICATION.md" ]; then
    c="$(grep -m1 'Criteria:' "$d/VERIFICATION.md" | sed -E 's/.*Criteria:\*\* ([0-9]+) pass, ([0-9]+) fail, of ([0-9]+).*/\1 \3/')"
    vpass="${c% *}"; vtotal="${c#* }"
    vresult="\"$(grep -m1 'Result:' "$d/VERIFICATION.md" | sed 's/.*Result:\*\* //')\""
  fi
  # scorecard first-pass
  sc_first="null"; sc_runs=0
  if [ -f "$GH" ]; then
    sc_first="$(jq -r --arg p "$p" '[.gates[]? | select(.type=="release-scorecard" and .phase==$p)] | if length==0 then "null" else (.[0].decision=="PASS"|tostring) end' "$GH")"
    sc_runs="$(jq --arg p "$p" '[.gates[]? | select(.type=="release-scorecard" and .phase==$p)] | length' "$GH")"
  fi
  blocks="$(grep -F "| $p |" "$GL" 2>/dev/null | wc -l | tr -d ' ')"
  stale="$(jq '[.entries[]? | select(.stale)] | length' "$d/evidence/index.json" 2>/dev/null || echo null)"
  runs="$(jq '.entries | length' "$d/evidence/index.json" 2>/dev/null || echo 0)"
  PHASES_JSON="$(printf '%s' "$PHASES_JSON" | jq -c --arg p "$p" --arg tier "${tier:-null}" --arg profile "$profile" \
    --arg first "$first" --arg rel "$released" --argjson lead "$lead" --argjson stages "$STAGES" \
    --argjson hdt "$hd_total" --argjson hdr "$hd_rework" --argjson vp "${vpass:-null}" --argjson vt "${vtotal:-null}" --argjson vr "$vresult" \
    --argjson scf "$sc_first" --argjson scr "$sc_runs" --argjson blocks "$blocks" --argjson stale "${stale:-null}" --argjson runs "${runs:-0}" \
    '. + [{phase:$p, tier:($tier|tonumber? // null), profile:(if $profile=="" then null else $profile end),
           started_at:(if $first=="" then null else $first end), released_at:(if $rel=="" then null else $rel end),
           lead_time_days:$lead, stage_days:$stages,
           decisions:{total:$hdt, rework:$hdr, rework_rate:(if $hdt>0 then ($hdr/$hdt) else null end)},
           evidence:{runs:$runs, stale:$stale, criteria_pass:$vp, criteria_total:$vt, coverage:(if ($vt//0)>0 then ($vp/$vt) else null end), verification:$vr},
           scorecard:{runs:$scr, first_pass:$scf}, guardrail_blocks:$blocks}]')"
done

# approval quality across the project
accepted="$(grep -c '^### \[HD-' "$HDF" 2>/dev/null)"; accepted=${accepted:-0}
rejected="$(grep -c 'REJECTED (Code 403' "$HDF" 2>/dev/null)"; rejected=${rejected:-0}
asserted="$(grep -c 'identity: asserted' "$HDF" 2>/dev/null)"; asserted=${asserted:-0}
# approval latency: checkpoint_published -> next decision.* for the same gate (hours)
LAT="$(awk -F'\t' '
  $3 ~ /^decision\.checkpoint_published: / { g=$3; sub(/^decision\.checkpoint_published: /,"",g); open[g]=$1 }
  $3 ~ /^decision\.(accepted|request_changes|request_verification|rejected|deferred): / { g=$3; sub(/^[^:]*: /,"",g); if (g in open) { print g"\t"open[g]"\t"$1; delete open[g] } }
' "$LTSV" | while IFS="$(printf '\t')" read -r g a b; do echo "$g $(( ($(epoch "$b") - $(epoch "$a")) / 60 ))"; done \
  | awk '{s[$1]+=$2; n[$1]++} END {printf "{"; k=0; for (g in s) printf "%s\"%s\":{\"mean_hours\":%.2f,\"n\":%d}", (k++?",":""), g, s[g]/n[g]/60, n[g]; printf "}"}')"
[ -z "$LAT" ] && LAT='{}'
GUARD="$( [ -f "$GL" ] && grep -E '^\| [0-9]{4}-' "$GL" | awk -F'|' '{gsub(/ /,"",$3); gsub(/ /,"",$4); print $3" "$4}' | sort | uniq -c \
  | awk '{printf "%s{\"hook\":\"%s\",\"code\":\"%s\",\"count\":%d}", (NR>1?",":""), $2, $3, $1}' )"
GUARD="[$GUARD]"

# DORA
releases="$(grep -cF 'stage.entered: released' "$LTSV")"
first_ev="$(head -1 "$LTSV" | cut -f1)"; last_ev="$(tail -1 "$LTSV" | cut -f1)"
span_days="null"; [ -n "$first_ev" ] && span_days="$(echo "scale=2; ($(epoch "$last_ev") - $(epoch "$first_ev")) / 86400" | bc)"
INC="$AIDLC_TRACK/incidents.json"
cfr="null"; mttr="null"; inc_n="null"
if [ -f "$INC" ]; then
  inc_n="$(jq '[.incidents[]? | select(.phase != null)] | length' "$INC")"
  [ "$releases" -gt 0 ] && cfr="$(jq --argjson r "$releases" '([.incidents[]? | select(.phase != null) | .phase] | unique | length) / $r' "$INC")"
  mttr="$(jq '[.incidents[]? | .restore_hours // empty] | if length==0 then null else (sort | .[(length/2|floor)]) end' "$INC")"
fi
tokens="$(cat "$AIDLC_TRACK"/runs/*.json 2>/dev/null | jq -s '[.[] | .usage.total_tokens? // empty] | if length==0 then null else add end')"
models="$(cut -f1- "$LIN" 2>/dev/null | grep -Eo 'model=[^ |]+' | sort -u | sed 's/model=//' | jq -R . | jq -sc .)"
BASE="null"; [ -f "$AIDLC_TRACK/baseline.json" ] && BASE="$(cat "$AIDLC_TRACK/baseline.json")"

jq -n --arg squad "$SQUAD" --arg asof "$(aidlc_now)" --argjson phases "$PHASES_JSON" \
  --argjson acc "$accepted" --argjson rej "$rejected" --argjson asr "$asserted" --argjson lat "$LAT" --argjson guard "$GUARD" \
  --argjson rel "$releases" --argjson span "$span_days" --argjson cfr "$cfr" --argjson mttr "$mttr" --argjson incn "$inc_n" \
  --argjson tokens "$tokens" --argjson models "$models" --argjson base "$BASE" '
  {as_of:$asof, squad:$squad, baseline:$base,
   dora:{releases:$rel, days_observed:$span,
         deployment_frequency_per_30d:(if ($span//0)>0 then ($rel*30/$span) else null end),
         lead_time_days_median:([$phases[] | .lead_time_days | select(.!=null)] | if length==0 then null else (sort|.[(length/2|floor)]) end),
         change_failure_rate:$cfr, incidents:$incn, time_to_restore_hours_median:$mttr},
   governance:{decisions_accepted:$acc, vague_attempts_rejected:$rej,
               structured_approval_rate:(if ($acc+$rej)>0 then ($acc/($acc+$rej)) else null end),
               asserted_identity_decisions:$asr, approval_latency:$lat, guardrail_blocks:$guard},
   quality:{evidence_coverage:([$phases[] | .evidence | select(.criteria_total!=null)] | if length==0 then null else ((map(.criteria_pass)|add)/(map(.criteria_total)|add)) end),
            rework_rate:([$phases[] | .decisions] | if (map(.total)|add // 0)==0 then null else ((map(.rework)|add)/(map(.total)|add)) end),
            scorecard_first_pass_rate:([$phases[] | .scorecard.first_pass | select(.!=null)] | if length==0 then null else (map(select(.))|length)/length end)},
   cost:{tokens_total:$tokens, note:"best effort: only agents that expose usage are counted"},
   models:$models, phases:$phases}' > "$OUTDIR/metrics.json"

jq -r '["phase","tier","profile","started_at","released_at","lead_time_days","decisions","rework","criteria_pass","criteria_total","scorecard_first_pass","guardrail_blocks"],
       (.phases[] | [.phase,.tier,.profile,.started_at,.released_at,.lead_time_days,.decisions.total,.decisions.rework,.evidence.criteria_pass,.evidence.criteria_total,.scorecard.first_pass,.guardrail_blocks]) | @csv' "$OUTDIR/metrics.json" > "$OUTDIR/phases.csv"
grep -E '^\| \*\*HD-' "$HDF" 2>/dev/null | awk -F'|' 'BEGIN{print "\"id\",\"time\",\"role\",\"decision\",\"status\""} {for(i=2;i<=6;i++){gsub(/^ +| +$|\*\*|`/,"",$i)}; printf "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n",$2,$3,$4,$5,$6}' > "$OUTDIR/decisions.csv"
jq -r '["hook","code","count"], (.governance.guardrail_blocks[] | [.hook,.code,.count]) | @csv' "$OUTDIR/metrics.json" > "$OUTDIR/guardrails.csv"
rm -f "$LTSV"
aidlc_lineage "-" "knowledge.metrics_extracted: $(jq '.phases|length' "$OUTDIR/metrics.json") phases" "$(aidlc_rel "$OUTDIR/metrics.json")" "$(aidlc_hash "$OUTDIR/metrics.json")"
echo "## METRICS READY"
jq -c '{dora, governance: (.governance | del(.guardrail_blocks)), quality}' "$OUTDIR/metrics.json"
