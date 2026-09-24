#!/bin/bash
# aidlc-console — build the read-only console as one self-contained HTML file.
# Usage: aidlc-console.sh [--data docs/aidlc/console-data] [--out docs/aidlc/console/index.html]
# Inlines portfolio, checkpoints, decisions, guardrails, metrics and index JSON into console.html.
# No backend, no network: open it from disk, a CI artifact or an internal static host behind SSO.
AIDLC_HOOK_NAME="aidlc-console"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
aidlc_require_jq
AIDLC_INPUT='{}'
DATA=""; OUT=""
while [ $# -gt 0 ]; do case "$1" in --data) DATA="$2"; shift 2 ;; --out) OUT="$2"; shift 2 ;; *) shift ;; esac; done
AIDLC_PROJECT="$(aidlc_project_dir)"
[ -z "$DATA" ] && DATA="$AIDLC_PROJECT/docs/aidlc/console-data"
[ -z "$OUT" ] && OUT="$AIDLC_PROJECT/docs/aidlc/console/index.html"
case "$DATA" in /*) ;; *) DATA="$AIDLC_PROJECT/$DATA" ;; esac
case "$OUT" in /*) ;; *) OUT="$AIDLC_PROJECT/$OUT" ;; esac
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL=""; for t in "$HERE/console.html" "$HERE/../../console/console.html"; do [ -f "$t" ] && { TPL="$t"; break; }; done
[ -n "$TPL" ] || { echo "aidlc-console: console.html template not found" >&2; exit 1; }
[ -d "$DATA" ] || { echo "aidlc-console: no data in $DATA; run aidlc-portfolio.sh first" >&2; exit 1; }
J='{}'
for f in portfolio checkpoints decisions guardrails metrics index; do
  [ -f "$DATA/$f.json" ] && J="$(printf '%s' "$J" | jq -c --arg k "$f" --slurpfile v "$DATA/$f.json" '. + {($k): $v[0]}')"
done
mkdir -p "$(dirname "$OUT")"
# </ inside JSON strings would close the script tag
JS="$(printf '%s' "$J" | sed 's#</#<\\/#g')"
AIDLC_CONSOLE_DATA="$JS" awk 'BEGIN { data = ENVIRON["AIDLC_CONSOLE_DATA"] } { i = index($0, "/*__AIDLC_DATA__*/{}"); if (i) { print substr($0, 1, i-1) data substr($0, i + length("/*__AIDLC_DATA__*/{}")) } else print }' "$TPL" > "$OUT"
echo "C00 console → $(aidlc_rel "$OUT") ($(wc -c < "$OUT" | tr -d ' ') bytes)"
