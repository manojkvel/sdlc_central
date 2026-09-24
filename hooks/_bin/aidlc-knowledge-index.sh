#!/bin/bash
# aidlc-knowledge-index — build docs/aidlc/index.json: wiki pages plus the track root's phases and decisions,
# so source-extract, the product manager and the console can find what the organisation knows with grep or jq.
# Usage: aidlc-knowledge-index.sh [--out docs/aidlc/index.json]
AIDLC_HOOK_NAME="aidlc-knowledge-index"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
aidlc_require_jq
AIDLC_INPUT='{}'
OUT=""; [ "$1" = "--out" ] && OUT="$2"
aidlc_load_state
[ -z "$OUT" ] && OUT="$AIDLC_PROJECT/docs/aidlc/index.json"
case "$OUT" in /*) ;; *) OUT="$AIDLC_PROJECT/$OUT" ;; esac
mkdir -p "$(dirname "$OUT")"
WIKI="$AIDLC_PROJECT/docs/aidlc/wiki"
fm() { awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f' "$1"; }
fmval() { fm "$1" | grep -E "^$2:" | head -1 | sed -E "s/^$2:[[:space:]]*//; s/^[\"']//; s/[\"']$//"; }
fmlist() { fm "$1" | awk -v k="$2" '$0 ~ "^"k":" { sub("^"k":[ \t]*",""); if ($0 ~ /^\[/) { gsub(/[\[\]]/,""); n=split($0,a,","); for(i=1;i<=n;i++){gsub(/^ +| +$/,"",a[i]); if(a[i]!="") print a[i]}; exit }; f=1; next } f && /^[ \t]*- / { sub(/^[ \t]*- /,""); print; next } f && /^[^ \t]/ { exit }'; }
STOP='^(the|and|for|with|that|this|from|are|was|were|into|when|each|every|which|their|there|than|then|have|has|not|but|its|per|all|any|can|will|must|only|also|over|under|about|after|before|between)$'
PAGES='[]'
if [ -d "$WIKI" ]; then
  for f in $(find "$WIKI" -type f -name '*.md' ! -name README.md | sort); do
    body="$(awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {f=0; b=1; next} b' "$f")"
    summary="$(printf '%s\n' "$body" | awk 'BEGIN{RS=""} !/^#/ {gsub(/\n/," "); print; exit}' | cut -c1-280)"
    terms="$(printf '%s' "$body" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9-' '\n' | awk 'length>3' | grep -Ev "$STOP" | sort | uniq -c | sort -rn | head -15 | awk '{print $2}' | jq -R . | jq -sc .)"
    PAGES="$(printf '%s' "$PAGES" | jq -c --arg id "$(fmval "$f" id)" --arg kind "$(fmval "$f" kind)" --arg title "$(fmval "$f" title)" \
      --arg owner "$(fmval "$f" owner)" --arg rb "$(fmval "$f" review_by)" --arg path "$(aidlc_rel "$f")" --arg summary "$summary" \
      --argjson sources "$(fmlist "$f" sources | jq -R . | jq -sc .)" --argjson links "$(fmlist "$f" links | jq -R . | jq -sc .)" --argjson terms "$terms" \
      '. + [{id:$id, kind:$kind, title:$title, owner:$owner, review_by:$rb, path:$path, summary:$summary, sources:$sources, links:$links, terms:$terms}]')"
  done
fi
PH='[]'
if aidlc_active; then
  for d in "$AIDLC_TRACK"/phases/*/; do
    [ -d "$d" ] || continue
    s="$d/SPEC.md"
    PH="$(printf '%s' "$PH" | jq -c --arg p "$(basename "$d")" --arg title "$(grep -m1 '^# ' "$s" 2>/dev/null | sed 's/^# //')" \
      --argjson acs "$(grep -Eo '(AC|SC)-[0-9]+' "$s" 2>/dev/null | sort -u | wc -l | tr -d ' ')" \
      --argjson reqs "$(grep -Eo 'REQ-[0-9]+' "$s" 2>/dev/null | sort -u | jq -R . | jq -sc .)" --arg path "$(aidlc_rel "${d%/}")" \
      '. + [{phase:$p, title:$title, criteria:$acs, requirements:$reqs, path:$path}]')"
  done
fi
DEC='[]'
if [ -f "$AIDLC_TRACK/human-decisions.md" ]; then
  DEC="$(awk '/^### \[HD-/ {id=$2; gsub(/[\[\]]/,"",id); t=$0; sub(/^### \[[^]]*\] /,"",t)} /\*\*Gate:\*\*/ && id!="" {g=$0; sub(/.*\*\*Gate:\*\* `/,"",g); sub(/`.*/,"",g); p=$0; sub(/.*\*\*Phase:\*\* `/,"",p); sub(/`.*/,"",p); st=$0; sub(/.*\*\*Status:\*\* /,"",st); printf "%s\t%s\t%s\t%s\t%s\n", id, t, g, p, st; id=""}' "$AIDLC_TRACK/human-decisions.md" \
    | jq -R 'split("\t") | {id:.[0], decision:.[1], gate:.[2], phase:.[3], status:.[4]}' | jq -sc .)"
fi
jq -n --arg asof "$(aidlc_now)" --argjson pages "$PAGES" --argjson phases "$PH" --argjson decisions "$DEC" \
  '{as_of:$asof, pages:$pages, phases:$phases, decisions:$decisions}' > "$OUT"
echo "K00 index: $(jq '.pages|length' "$OUT") wiki page(s), $(jq '.phases|length' "$OUT") phase(s), $(jq '.decisions|length' "$OUT") decision(s) → $(aidlc_rel "$OUT")"
