#!/bin/bash
# ------------------------------------------------------------------
# aidlc-usage — record real model token usage per session and phase (Claude Code, on every Stop).
# ------------------------------------------------------------------
# Input (stdin): {transcript_path, session_id, cwd}. Reads only the transcript lines added since the last
# run, sums message.usage once per message id (a response is split across several transcript lines that
# repeat the same usage), and adds it to the CURRENT_PHASE bucket in <track>/runs/usage/<session>.json.
# Never blocks: always exits 0. No model calls. Other agents do not expose usage, so their cost stays null.
# ------------------------------------------------------------------
AIDLC_HOOK_NAME="aidlc-usage"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
command -v jq >/dev/null 2>&1 || exit 0
aidlc_read_input
aidlc_load_state
aidlc_active || exit 0
TP="$(aidlc_field .transcript_path)"; SID="$(aidlc_field .session_id)"
[ -n "$TP" ] && [ -f "$TP" ] || exit 0
[ -z "$SID" ] && SID="$(basename "$TP" .jsonl)"
DIR="$AIDLC_TRACK/runs/usage"; mkdir -p "$DIR"
OUT="$DIR/$SID.json"
[ -f "$OUT" ] || jq -n --arg s "$SID" '{session:$s, agent:"claude-code", cursor:0, last_id:null, models:[], by_phase:{}}' > "$OUT"
CURSOR="$(jq -r '.cursor' "$OUT")"; LAST="$(jq -r '.last_id // ""' "$OUT")"
TOTAL="$(wc -l < "$TP" | tr -d ' ')"
[ "$TOTAL" -le "$CURSOR" ] && exit 0
PH="$AIDLC_PHASE"
DELTA="$(tail -n +"$((CURSOR + 1))" "$TP" | head -n "$((TOTAL - CURSOR))" \
  | jq -c 'select(.type=="assistant" and .message.usage != null and .message.id != null and .message.model != "<synthetic>") | {id:.message.id, model:.message.model, u:.message.usage}' 2>/dev/null \
  | jq -s --arg last "$LAST" '
      (map(select(.id != $last)) | unique_by(.id)) as $m
      | {messages: ($m|length), last_id: (if length>0 then .[-1].id else $last end), models: ($m | map(.model) | unique),
         input: ($m|map(.u.input_tokens // 0)|add // 0), output: ($m|map(.u.output_tokens // 0)|add // 0),
         cache_read: ($m|map(.u.cache_read_input_tokens // 0)|add // 0), cache_creation: ($m|map(.u.cache_creation_input_tokens // 0)|add // 0)}')"
[ -z "$DELTA" ] && exit 0
TMP="$(mktemp)"
jq --argjson d "$DELTA" --arg p "$PH" --argjson c "$TOTAL" --arg now "$(aidlc_now)" '
  .cursor = $c | .last_id = $d.last_id | .updated_at = $now | .models = ((.models + $d.models) | unique)
  | .by_phase[$p] = ((.by_phase[$p] // {messages:0,input:0,output:0,cache_read:0,cache_creation:0}) as $b
      | {messages:($b.messages+$d.messages), input:($b.input+$d.input), output:($b.output+$d.output),
         cache_read:($b.cache_read+$d.cache_read), cache_creation:($b.cache_creation+$d.cache_creation)})' "$OUT" > "$TMP" && cat "$TMP" > "$OUT"
rm -f "$TMP"
exit 0
