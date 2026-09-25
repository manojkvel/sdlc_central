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
  # test first: tasks whose red run (--red, exit != 0) precedes their latest passing run; waivers counted apart
  TF='null'
  if [ -f "$d/TASKS.md" ]; then
    tf_n=0; tf_p=0; tf_w=0
    for t in $(grep -Eo 'TASK-[0-9]+' "$d/TASKS.md" | awk '!s[$0]++'); do
      tf_n=$((tf_n+1))
      if awk -v t="$t" '$0 ~ (t "([^0-9]|$)") && !f {f=1} f && $0 !~ t && /TASK-[0-9]+/ {exit} f' "$d/TASKS.md" | grep -Eiq '(red|verify)[^a-z]*:[[:space:]]*n/a'; then tf_w=$((tf_w+1)); continue; fi
      [ -f "$d/evidence/index.json" ] && jq -e --arg t "$t" '
        def n: .id | ltrimstr("E-") | tonumber;
        ([.entries[] | select(.task == $t and .expect != "fail" and .exit_code == 0) | n] | max) as $g
        | $g != null and ([.entries[] | select(.task == $t and .expect == "fail" and .exit_code != 0) | n | select(. < $g)] | length > 0)' \
        "$d/evidence/index.json" >/dev/null 2>&1 && tf_p=$((tf_p+1))
    done
    TF="{\"tasks\":$tf_n,\"proven\":$tf_p,\"waived\":$tf_w}"
  fi
  # gate wait: hours from each checkpoint on this phase's artifacts to the decision that closed it
  GW="$(awk -F'\t' -v p="/phases/$p/" '
    index($4,p) && $3 ~ /^decision\.checkpoint_published: / { g=$3; sub(/^[^:]*: /,"",g); open[g]=$1 }
    index($4,p) && $3 ~ /^decision\.(accepted|approved_with_risk|request_changes|request_verification|rejected|deferred): / { g=$3; sub(/^[^:]*: /,"",g); if (g in open) { print open[g]"\t"$1; delete open[g] } }
  ' "$LTSV" | while IFS="$(printf '\t')" read -r a b; do echo $(( $(epoch "$b") - $(epoch "$a") )); done | awk '{s+=$1; n++} END {if (n) printf "%.2f", s/3600; else printf "null"}')"
  [ -z "$GW" ] && GW=null
  stale="$(jq '[.entries[]? | select(.stale)] | length' "$d/evidence/index.json" 2>/dev/null || echo null)"
  runs="$(jq '.entries | length' "$d/evidence/index.json" 2>/dev/null || echo 0)"
  PHASES_JSON="$(printf '%s' "$PHASES_JSON" | jq -c --arg p "$p" --arg tier "${tier:-null}" --arg profile "$profile" \
    --arg first "$first" --arg rel "$released" --argjson lead "$lead" --argjson stages "$STAGES" \
    --argjson hdt "$hd_total" --argjson hdr "$hd_rework" --argjson vp "${vpass:-null}" --argjson vt "${vtotal:-null}" --argjson vr "$vresult" \
    --argjson scf "$sc_first" --argjson scr "$sc_runs" --argjson blocks "$blocks" --argjson stale "${stale:-null}" --argjson runs "${runs:-0}" \
    --argjson tf "$TF" --argjson gw "$GW" \
    '. + [{phase:$p, tier:($tier|tonumber? // null), profile:(if $profile=="" then null else $profile end),
           started_at:(if $first=="" then null else $first end), released_at:(if $rel=="" then null else $rel end),
           lead_time_days:$lead, stage_days:$stages,
           decisions:{total:$hdt, rework:$hdr, rework_rate:(if $hdt>0 then ($hdr/$hdt) else null end)},
           evidence:{runs:$runs, stale:$stale, criteria_pass:$vp, criteria_total:$vt, coverage:(if ($vt//0)>0 then ($vp/$vt) else null end), verification:$vr},
           scorecard:{runs:$scr, first_pass:$scf}, guardrail_blocks:$blocks, test_first:$tf, gate_wait_hours:$gw}]')"
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
# earliest and latest timestamps, not first and last lines: migrated or merged lineage can be out of order
first_ev="$(cut -f1 "$LTSV" | sort | head -1)"; last_ev="$(cut -f1 "$LTSV" | sort | tail -1)"
span_days="null"; [ -n "$first_ev" ] && span_days="$(echo "scale=2; ($(epoch "$last_ev") - $(epoch "$first_ev")) / 86400" | bc)"
INC="$AIDLC_TRACK/incidents.json"
cfr="null"; mttr="null"; inc_n="null"
if [ -f "$INC" ]; then
  inc_n="$(jq '[.incidents[]? | select(.phase != null)] | length' "$INC")"
  [ "$releases" -gt 0 ] && cfr="$(jq --argjson r "$releases" '([.incidents[]? | select(.phase != null) | .phase] | unique | length) / $r' "$INC")"
  mttr="$(jq '[.incidents[]? | .restore_hours // empty] | if length==0 then null else (sort | .[(length/2|floor)]) end' "$INC")"
fi
# Real usage recorded by aidlc-usage.sh (Claude Code Stop hook), per session and phase.
USAGE="$(cat "$AIDLC_TRACK"/runs/usage/*.json 2>/dev/null | jq -s '
  if length == 0 then null else
  { sessions: length,
    by_phase: (reduce (.[] | .by_phase | to_entries[]) as $e ({};
      .[$e.key] = ((.[$e.key] // {messages:0,input:0,output:0,cache_read:0,cache_creation:0}) as $b
        | {messages:($b.messages+$e.value.messages), input:($b.input+$e.value.input), output:($b.output+$e.value.output),
           cache_read:($b.cache_read+$e.value.cache_read), cache_creation:($b.cache_creation+$e.value.cache_creation)}))) }
  | .totals = ([.by_phase[]] | {messages:(map(.messages)|add), input:(map(.input)|add), output:(map(.output)|add),
                                cache_read:(map(.cache_read)|add), cache_creation:(map(.cache_creation)|add)})
  | .totals.total = (.totals.input + .totals.output + .totals.cache_read + .totals.cache_creation)
  end')"
[ -z "$USAGE" ] && USAGE=null
models="$(cut -f1- "$LIN" 2>/dev/null | grep -Eo 'model=[^ |]+' | sort -u | sed 's/model=//' | jq -R . | jq -sc .)"
BASE="null"; [ -f "$AIDLC_TRACK/baseline.json" ] && BASE="$(cat "$AIDLC_TRACK/baseline.json")"
# A track generated for demos and UI tests carries a SAMPLE marker; every view then says so.
SAMPLE=false; [ -f "$AIDLC_TRACK/SAMPLE" ] && SAMPLE=true

jq -n --arg squad "$SQUAD" --arg asof "$(aidlc_now)" --argjson phases "$PHASES_JSON" \
  --argjson acc "$accepted" --argjson rej "$rejected" --argjson asr "$asserted" --argjson lat "$LAT" --argjson guard "$GUARD" \
  --argjson rel "$releases" --argjson span "$span_days" --argjson cfr "$cfr" --argjson mttr "$mttr" --argjson incn "$inc_n" \
  --argjson usage "$USAGE" --argjson models "$models" --argjson base "$BASE" --argjson sample "$SAMPLE" '
  {as_of:$asof, squad:$squad, baseline:$base} + (if $sample then {sample:true} else {} end) + {
   dora:{releases:$rel, days_observed:$span,
         deployment_frequency_per_30d:(if ($span//0)>0 then ($rel*30/$span) else null end),
         lead_time_days_median:([$phases[] | .lead_time_days | select(.!=null)] | if length==0 then null else (sort|.[(length/2|floor)]) end),
         change_failure_rate:$cfr, incidents:$incn, time_to_restore_hours_median:$mttr},
   governance:{decisions_accepted:$acc, vague_attempts_rejected:$rej,
               structured_approval_rate:(if ($acc+$rej)>0 then ($acc/($acc+$rej)) else null end),
               asserted_identity_decisions:$asr, approval_latency:$lat, guardrail_blocks:$guard,
               gate_wait_share:([$phases[] | select(.lead_time_days != null and .lead_time_days > 0 and .gate_wait_hours != null)]
                 | if length==0 then null else ((map(.gate_wait_hours)|add) / 24 / (map(.lead_time_days)|add)) end)},
   quality:{evidence_coverage:([$phases[] | .evidence | select(.criteria_total!=null)] | if length==0 then null else ((map(.criteria_pass)|add)/(map(.criteria_total)|add)) end),
            rework_rate:([$phases[] | .decisions] | if (map(.total)|add // 0)==0 then null else ((map(.rework)|add)/(map(.total)|add)) end),
            scorecard_first_pass_rate:([$phases[] | .scorecard.first_pass | select(.!=null)] | if length==0 then null else (map(select(.))|length)/length end),
            test_first_rate:([$phases[] | .test_first | select(. != null)] | (map(.tasks - .waived) | add // 0) as $d
              | if $d == 0 then null else ((map(.proven)|add) / $d) end),
            test_first_tasks:([$phases[] | .test_first | select(. != null)] | {tasks:(map(.tasks)|add // 0), proven:(map(.proven)|add // 0), waived:(map(.waived)|add // 0)})},
   cost:(if $usage == null then {tokens_total:null, note:"no usage recorded: only Claude Code sessions with the aidlc-usage Stop hook are measured"}
         else {tokens_total:$usage.totals.total, input:$usage.totals.input, output:$usage.totals.output,
               cache_read:$usage.totals.cache_read, cache_creation:$usage.totals.cache_creation, messages:$usage.totals.messages,
               sessions:$usage.sessions,
               per_tier:([$phases[] | {tier, t: ($usage.by_phase[.phase] // null)}] | map(select(.t != null)) | group_by(.tier)
                 | map({tier: .[0].tier, units: length, tokens_per_unit: ((map(.t.input+.t.output+.t.cache_read+.t.cache_creation)|add) / length)})),
               note:"measured from Claude Code transcripts; cache reads are billed at a fraction of input"} end),
   models:$models, phases:($phases | map(. + {tokens: (if $usage == null then null else ($usage.by_phase[.phase] // null) end)}))}' > "$OUTDIR/metrics.json"

jq -r '["phase","tier","profile","started_at","released_at","lead_time_days","decisions","rework","criteria_pass","criteria_total","scorecard_first_pass","guardrail_blocks"],
       (.phases[] | [.phase,.tier,.profile,.started_at,.released_at,.lead_time_days,.decisions.total,.decisions.rework,.evidence.criteria_pass,.evidence.criteria_total,.scorecard.first_pass,.guardrail_blocks]) | @csv' "$OUTDIR/metrics.json" > "$OUTDIR/phases.csv"
grep -E '^\| \*\*HD-' "$HDF" 2>/dev/null | awk -F'|' 'BEGIN{print "\"id\",\"time\",\"role\",\"decision\",\"status\""} {for(i=2;i<=6;i++){gsub(/^ +| +$|\*\*|`/,"",$i)}; printf "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"\n",$2,$3,$4,$5,$6}' > "$OUTDIR/decisions.csv"
jq -r '["hook","code","count"], (.governance.guardrail_blocks[] | [.hook,.code,.count]) | @csv' "$OUTDIR/metrics.json" > "$OUTDIR/guardrails.csv"
rm -f "$LTSV"
aidlc_lineage "-" "knowledge.metrics_extracted: $(jq '.phases|length' "$OUTDIR/metrics.json") phases" "$(aidlc_rel "$OUTDIR/metrics.json")" "$(aidlc_hash "$OUTDIR/metrics.json")"
echo "## METRICS READY"
jq -c '{dora, governance: (.governance | del(.guardrail_blocks)), quality}' "$OUTDIR/metrics.json"
