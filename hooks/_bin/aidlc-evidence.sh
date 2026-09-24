#!/bin/bash
# ------------------------------------------------------------------
# aidlc-evidence — run a command and record it as evidence for a task.
# ------------------------------------------------------------------
# Usage:
#   aidlc-evidence.sh run --task TASK-003 [--ac AC-1,AC-2] [--kind test|build|lint|uat|contract]
#                         [--suite] [--report <path>] [--files a,b] -- <command ...>
#   aidlc-evidence.sh list [--phase NN-slug]
#
# Writes, under <track root>/phases/<phase>/evidence/:
#   <TASK>/<NNN>-<slug>.out | .err     command output (gitignored bodies)
#   index.json                         one entry per run: task, acs, kind, command, exit code,
#                                      output hashes, touched files and their hashes
# and a lineage line `evidence.recorded`. Exits with the command's own exit code.
#
# Touched files default to the working-tree changes (git diff vs HEAD plus untracked),
# excluding the track root. Their hashes are what make evidence go stale when source
# changes after the run.
# ------------------------------------------------------------------
AIDLC_HOOK_NAME="aidlc-evidence"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
aidlc_require_jq
AIDLC_INPUT='{}'

SUB="$1"; shift
TASK=""; ACS=""; KIND="test"; SUITE=false; REPORT=""; FILES=""; PHASE_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --task) TASK="$2"; shift 2 ;;
    --ac|--acs) ACS="$2"; shift 2 ;;
    --kind) KIND="$2"; shift 2 ;;
    --suite) SUITE=true; shift ;;
    --report) REPORT="$2"; shift 2 ;;
    --files) FILES="$2"; shift 2 ;;
    --phase) PHASE_ARG="$2"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done

aidlc_load_state
if ! aidlc_active; then echo "aidlc-evidence: no track root at $(aidlc_rel "$AIDLC_TRACK"); run setup/init-track.sh" >&2; exit 1; fi
[ -n "$PHASE_ARG" ] && { AIDLC_PHASE="$PHASE_ARG"; AIDLC_PHASE_DIR="$AIDLC_TRACK/phases/$PHASE_ARG"; }
if [ "$AIDLC_PHASE" = "none" ] || [ ! -d "$AIDLC_PHASE_DIR" ]; then echo "aidlc-evidence: no active phase" >&2; exit 1; fi
EV="$AIDLC_PHASE_DIR/evidence"
IDX="$EV/index.json"
mkdir -p "$EV"
[ -f "$IDX" ] || echo '{"version":1,"entries":[]}' > "$IDX"

if [ "$SUB" = "list" ]; then
  jq -r '.entries[] | "\(.id)  \(.task)  exit=\(.exit_code)  stale=\(.stale)  \(.kind)  \(.command)"' "$IDX"
  exit 0
fi
[ "$SUB" = "run" ] || { echo "usage: aidlc-evidence.sh run --task TASK-NNN [...] -- <command>" >&2; exit 64; }
[ -n "$TASK" ] || { echo "aidlc-evidence: --task is required" >&2; exit 64; }
[ $# -gt 0 ] || { echo "aidlc-evidence: no command after --" >&2; exit 64; }
CMD="$*"

N=$(( $(jq '.entries | length' "$IDX") + 1 ))
ID="$(printf 'E-%03d' "$N")"
SLUG="$(printf '%s' "$CMD" | tr -cs 'A-Za-z0-9' '-' | cut -c1-40 | sed 's/-*$//')"
mkdir -p "$EV/$TASK"
OUT="$EV/$TASK/$(printf '%03d' "$N")-$SLUG.out"
ERR="$EV/$TASK/$(printf '%03d' "$N")-$SLUG.err"

START="$(aidlc_now)"; T0="$(perl -MTime::HiRes=time -e 'printf "%d", time()*1000' 2>/dev/null || echo 0)"
( cd "$AIDLC_PROJECT" && bash -c "$CMD" ) >"$OUT" 2>"$ERR"
RC=$?
T1="$(perl -MTime::HiRes=time -e 'printf "%d", time()*1000' 2>/dev/null || echo 0)"
END="$(aidlc_now)"

# Touched files and their hashes.
TRACK_REL="$(aidlc_rel "$AIDLC_TRACK")"
if [ -n "$FILES" ]; then
  LIST="$(printf '%s' "$FILES" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d')"
else
  LIST="$( (cd "$AIDLC_PROJECT" && { git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; }) \
          | grep -v "^$TRACK_REL/" | sort -u)"
fi
TF_JSON='[]'
OLDIFS="$IFS"; IFS='
'
for f in $LIST; do
  h="$(aidlc_hash "$AIDLC_PROJECT/$f")"
  TF_JSON="$(printf '%s' "$TF_JSON" | jq -c --arg p "$f" --arg h "$h" '. + [{path:$p, sha256:$h}]')"
done
IFS="$OLDIFS"
TOUCHED_HASH="$(printf '%s' "$TF_JSON" | jq -r '.[] | "\(.path):\(.sha256)"' | sort | shasum -a 256 | cut -c1-64)"

REPORT_REL=""; REPORT_HASH=""
if [ -n "$REPORT" ]; then
  RA="$(aidlc_abs "$REPORT")"
  if [ -f "$RA" ]; then
    cp "$RA" "$EV/$TASK/$(printf '%03d' "$N")-report.$(printf '%s' "$RA" | sed 's/.*\.//')"
    REPORT_REL="evidence/$TASK/$(printf '%03d' "$N")-report.$(printf '%s' "$RA" | sed 's/.*\.//')"
    REPORT_HASH="$(aidlc_hash "$RA")"
  fi
fi

ACS_JSON="$(printf '%s' "$ACS" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d' | jq -R . | jq -sc .)"
TMP="$(mktemp)"
jq --arg id "$ID" --arg task "$TASK" --argjson acs "$ACS_JSON" --arg kind "$KIND" --argjson suite "$SUITE" \
   --arg cmd "$CMD" --arg cmdh "$(printf '%s' "$CMD" | shasum -a 256 | cut -c1-16)" --arg cwd "$(aidlc_rel "$AIDLC_PROJECT")" \
   --arg start "$START" --arg end "$END" --argjson dur "$((T1 - T0))" --argjson rc "$RC" \
   --arg out "evidence/$TASK/$(basename "$OUT")" --arg err "evidence/$TASK/$(basename "$ERR")" \
   --arg outh "$(aidlc_hash "$OUT")" --arg errh "$(aidlc_hash "$ERR")" \
   --arg rep "$REPORT_REL" --arg reph "$REPORT_HASH" --argjson tf "$TF_JSON" --arg th "$TOUCHED_HASH" \
   --arg model "${AIDLC_MODEL:-unknown}" --arg sdlc "$AIDLC_SDLC_VERSION" \
   '.entries += [{id:$id, task:$task, acs:$acs, kind:$kind, suite:$suite, command:$cmd, command_hash:$cmdh, cwd:$cwd,
      started_at:$start, finished_at:$end, duration_ms:$dur, exit_code:$rc,
      stdout_path:$out, stdout_sha256:$outh, stderr_path:$err, stderr_sha256:$errh,
      report_path:(if $rep=="" then null else $rep end), report_sha256:(if $reph=="" then null else $reph end),
      touched_files:$tf, touched_hash:$th, stale:false, model:$model, sdlc:$sdlc}]' "$IDX" > "$TMP" && cat "$TMP" > "$IDX"
rm -f "$TMP"

aidlc_lineage "$ID" "evidence.recorded: $TASK $KIND exit=$RC" "$(aidlc_rel "$IDX")" "$(aidlc_hash "$IDX")"

# Show the agent what happened, briefly.
tail -n 25 "$OUT"
[ -s "$ERR" ] && { echo "--- stderr (last 15 lines)"; tail -n 15 "$ERR"; }
echo "AIDLC EVIDENCE $ID recorded for $TASK: exit $RC, $(printf '%s' "$TF_JSON" | jq 'length') touched file(s), log $(aidlc_rel "$OUT")"
exit $RC
