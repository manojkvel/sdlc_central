#!/bin/bash
# ------------------------------------------------------------------
# aidlc-wiki-lint — keep docs/aidlc/wiki/ citable, owned, current and consistent.
# ------------------------------------------------------------------
# Usage: aidlc-wiki-lint.sh [--wiki <dir>] [--stale-only]
#   L01 frontmatter missing a required key (id, kind, title, owner, sources, review_by)
#   L02 unknown kind (service, contract, team, domain, decision-theme, incident-class, runbook)
#   L03 a body paragraph cites no source ([...] reference)
#   L04 a source does not resolve (file, HD/D/RISK id, or an explicit external: / hub: prefix)
#   L05 orphan page (no inbound links) when the wiki has more than one page
#   L06 page past its review_by date
#   L07 two pages assert different values for the same `facts:` key
#   L08 links to a page that does not exist
# Exit 0 clean ("L00 wiki clean"), 2 with every finding listed.
# --stale-only runs L06 only and writes the list into state.md under "## Stale knowledge".
# ------------------------------------------------------------------
AIDLC_HOOK_NAME="aidlc-wiki-lint"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
AIDLC_INPUT='{}'
WIKI=""; STALE_ONLY=0
while [ $# -gt 0 ]; do case "$1" in --wiki) WIKI="$2"; shift 2 ;; --stale-only) STALE_ONLY=1; shift ;; *) shift ;; esac; done
AIDLC_PROJECT="$(aidlc_project_dir)"; AIDLC_TRACK="$(aidlc_track_root "$AIDLC_PROJECT")"
[ -z "$WIKI" ] && WIKI="$AIDLC_PROJECT/docs/aidlc/wiki"
[ -d "$WIKI" ] || { echo "L00 no wiki at $(aidlc_rel "$WIKI")"; exit 0; }
TODAY="$(date -u +%Y-%m-%d)"
FIND="$(mktemp)"; FACTS="$(mktemp)"; LINKS="$(mktemp)"; IDS="$(mktemp)"
fm() { awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {exit} f' "$1"; }
fmval() { fm "$1" | grep -E "^$2:" | head -1 | sed -E "s/^$2:[[:space:]]*//; s/^[\"']//; s/[\"']$//"; }
fmlist() { # inline [a, b] or block "- a" lists
  fm "$1" | awk -v k="$2" '
    $0 ~ "^"k":" { v=$0; sub("^"k":[ \t]*",""); if ($0 ~ /^\[/) { gsub(/[\[\]]/,""); n=split($0,a,","); for(i=1;i<=n;i++){gsub(/^ +| +$/,"",a[i]); if(a[i]!="") print a[i]}; exit } ; f=1; next }
    f && /^[ \t]*- / { sub(/^[ \t]*- /,""); print; next }
    f && /^[^ \t]/ { exit }'
}
PAGES="$(find "$WIKI" -type f -name '*.md' ! -name 'README.md' | sort)"
NPAGES="$(printf '%s\n' "$PAGES" | sed '/^$/d' | wc -l | tr -d ' ')"
for f in $PAGES; do
  rel="$(aidlc_rel "$f")"; id="$(fmval "$f" id)"
  [ -n "$id" ] && echo "$id" >> "$IDS"
  rb="$(fmval "$f" review_by)"
  if [ -n "$rb" ] && [ "$rb" \< "$TODAY" ]; then echo "L06 $rel: past review_by $rb (owner $(fmval "$f" owner))" >> "$FIND"; fi
  [ $STALE_ONLY -eq 1 ] && continue
  for k in id kind title owner review_by; do [ -z "$(fmval "$f" $k)" ] && echo "L01 $rel: frontmatter missing $k" >> "$FIND"; done
  [ -z "$(fmlist "$f" sources)" ] && echo "L01 $rel: frontmatter missing sources" >> "$FIND"
  case "$(fmval "$f" kind)" in service|contract|team|domain|decision-theme|incident-class|runbook|"") ;; *) echo "L02 $rel: unknown kind $(fmval "$f" kind)" >> "$FIND" ;; esac
  for s in $(fmlist "$f" sources); do
    path="${s%%#*}"
    case "$s" in external:*|hub:*|hub/*) continue ;; esac
    if printf '%s' "$s" | grep -Eq '^(HD|D|DEC|RISK|ADR)-[0-9]+$'; then
      grep -rqs "$s" "$AIDLC_TRACK" "$AIDLC_PROJECT/docs/aidlc/decisions" || echo "L04 $rel: source $s not found in the track root or ADRs" >> "$FIND"
    elif [ ! -e "$AIDLC_PROJECT/$path" ]; then echo "L04 $rel: source $s does not resolve" >> "$FIND"; fi
  done
  # body paragraphs must carry a [citation]
  awk 'NR==1 && /^---$/ {f=1; next} f && /^---$/ {f=0; body=1; next} body' "$f" \
    | awk 'BEGIN{RS=""} { p=$0; if (p ~ /^#/ || p ~ /^\|/ || p ~ /^```/) next; if (p !~ /\[[^]]+\]/) { gsub(/\n/," ",p); print substr(p,1,60) } }' \
    | while read -r para; do echo "L03 $rel: uncited paragraph \"$para...\"" >> "$FIND"; done
  for l in $(fmlist "$f" links); do echo "$id $l" >> "$LINKS"; done
  fm "$f" | awk '/^facts:/ {f=1; next} f && /^[ \t]+[A-Za-z0-9_.-]+:/ {k=$1; sub(/:$/,"",k); v=$0; sub(/^[^:]*:[ \t]*/,"",v); print k"\t"v; next} f && /^[^ \t]/ {exit}' \
    | while IFS="$(printf '\t')" read -r k v; do printf '%s\t%s\t%s\n' "$k" "$v" "$rel" >> "$FACTS"; done
done
if [ $STALE_ONLY -eq 0 ]; then
  while read -r from to; do grep -qx "$to" "$IDS" || echo "L08 $from: links to missing page $to" >> "$FIND"; done < "$LINKS"
  if [ "$NPAGES" -gt 1 ]; then
    while read -r id; do awk -v t="$id" '$2==t' "$LINKS" | grep -q . || echo "L05 $id: orphan page (no inbound links)" >> "$FIND"; done < "$IDS"
  fi
  sort "$FACTS" | awk -F'\t' '{ if ($1 in v && v[$1] != $2) print "L07 fact " $1 ": \"" v[$1] "\" in " w[$1] " vs \"" $2 "\" in " $3; v[$1]=$2; w[$1]=$3 }' >> "$FIND"
fi
if [ $STALE_ONLY -eq 1 ] && [ -f "$AIDLC_TRACK/state.md" ]; then
  TMP="$(mktemp)"; awk '/^## Stale knowledge/ {skip=1; next} skip && /^## / {skip=0} !skip' "$AIDLC_TRACK/state.md" > "$TMP"
  if [ -s "$FIND" ]; then { printf '\n## Stale knowledge\n'; sed 's/^L06 /- /' "$FIND"; } >> "$TMP"; fi
  cat "$TMP" > "$AIDLC_TRACK/state.md"; rm -f "$TMP"
fi
if [ -s "$FIND" ]; then cat "$FIND" >&2; N="$(wc -l < "$FIND" | tr -d ' ')"; rm -f "$FIND" "$FACTS" "$LINKS" "$IDS"
  echo "AIDLC BLOCK aidlc-wiki-lint: ${N} finding(s) in the wiki" >&2; exit 2; fi
rm -f "$FIND" "$FACTS" "$LINKS" "$IDS"
echo "L00 wiki clean ($NPAGES page(s))"
