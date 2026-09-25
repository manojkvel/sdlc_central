#!/bin/bash
# aidlc-console — build the read-only console and the Measurement Bench as self-contained HTML files.
# Usage: aidlc-console.sh [--data docs/aidlc/console-data] [--out docs/aidlc/console/index.html]
# Writes <out> (console, with a Bench tab) and bench.html beside it (the full bench with the value model).
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
tpl() { for t in "$HERE/$1" "$HERE/../../console/$1"; do [ -f "$t" ] && { echo "$t"; return; }; done; }
TPL="$(tpl console.html)"; BTPL="$(tpl bench.html)"; BJS="$(tpl bench.js)"
[ -n "$TPL" ] || { echo "aidlc-console: console.html template not found" >&2; exit 1; }
[ -d "$DATA" ] || { echo "aidlc-console: no data in $DATA; run aidlc-portfolio.sh first" >&2; exit 1; }
J='{}'
for f in portfolio checkpoints decisions guardrails metrics index; do
  [ -f "$DATA/$f.json" ] && J="$(printf '%s' "$J" | jq -c --arg k "$f" --slurpfile v "$DATA/$f.json" '. + {($k): $v[0]}')"
done
mkdir -p "$(dirname "$OUT")"
# </ inside JSON strings would close the script tag
JS="$(printf '%s' "$J" | sed 's#</#<\\/#g')"
BENCH_JS=""; [ -n "$BJS" ] && BENCH_JS="$(sed 's#</#<\\/#g' "$BJS")"
# fill <template> <output>: inline the data and the shared bench renderer (values passed through ENVIRON, not awk -v)
fill() {
  AIDLC_CONSOLE_DATA="$JS" AIDLC_BENCH_JS="$BENCH_JS" awk '
    BEGIN { data = ENVIRON["AIDLC_CONSOLE_DATA"]; js = ENVIRON["AIDLC_BENCH_JS"]; d = "/*__AIDLC_DATA__*/{}"; b = "/*__AIDLC_BENCH_JS__*/" }
    { i = index($0, d); if (i) $0 = substr($0, 1, i-1) data substr($0, i + length(d))
      j = index($0, b); if (j) $0 = substr($0, 1, j-1) js substr($0, j + length(b))
      print }' "$1" > "$2"
}
fill "$TPL" "$OUT"
echo "C00 console → $(aidlc_rel "$OUT") ($(wc -c < "$OUT" | tr -d ' ') bytes)"
if [ -n "$BTPL" ] && [ -n "$BJS" ]; then
  BOUT="$(dirname "$OUT")/bench.html"
  fill "$BTPL" "$BOUT"
  echo "C00 bench → $(aidlc_rel "$BOUT") ($(wc -c < "$BOUT" | tr -d ' ') bytes)"
fi
