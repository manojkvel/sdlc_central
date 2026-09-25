#!/bin/bash
# ------------------------------------------------------------------
# aidlc-evidence — run a command and record it as evidence for a task.
# ------------------------------------------------------------------
# Usage:
#   aidlc-evidence.sh run --task TASK-003 [--ac AC-1,AC-2] [--kind test|build|lint|uat|contract]
#                         [--suite] [--report <path>] [--files a,b] [--red] -- <command ...>
#     --red  test-first proof: run the new test BEFORE the change. It must fail. A red run that passes
#            proves nothing and exits 3. Red runs never count as passing evidence; the verifier requires
#            one per task (before its passing run) when red_green_required is on.
#   aidlc-evidence.sh list [--all] [--phase NN-slug]   latest run per command, one line each
#   aidlc-evidence.sh summary [--phase NN-slug]        counts plus failing and stale runs only
#   aidlc-evidence.sh compact [--phase NN-slug]        move old inline touched-file lists into manifests
#
# Writes, under <track root>/phases/<phase>/evidence/:
#   <TASK>/<NNN>-<slug>.out | .err     command output (gitignored bodies)
#   <TASK>/<NNN>-touched.tsv           touched files and their hashes (committed)
#   index.json                         one small entry per run: task, acs, kind, command, exit code,
#                                      output hashes, touched count, manifest path and hash
# and a lineage line `evidence.recorded`. Exits with the command's own exit code (for --red: 0 when it failed
# as expected, 3 when it passed).
#
# Touched files: --files, else the backticked paths in the task's TASKS.md block, else the working-tree
# changes (documents and images excluded, track root excluded). Their hashes make evidence go stale when source
# changes after the run.
# ------------------------------------------------------------------
AIDLC_HOOK_NAME="aidlc-evidence"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
aidlc_require_jq
AIDLC_INPUT='{}'

SUB="$1"; shift
TASK=""; ACS=""; KIND="test"; SUITE=false; REPORT=""; FILES=""; PHASE_ARG=""; RED=false
while [ $# -gt 0 ]; do
  case "$1" in
    --task) TASK="$2"; shift 2 ;;
    --ac|--acs) ACS="$2"; shift 2 ;;
    --kind) KIND="$2"; shift 2 ;;
    --suite) SUITE=true; shift ;;
    --red|--expect-fail) RED=true; shift ;;
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

# Read-side commands: agents use these instead of reading index.json.
if [ "$SUB" = "list" ]; then
  # latest run per command only; --all shows superseded runs too
  ALL=false; [ "$1" = "--all" ] && ALL=true
  jq -r --argjson all "$ALL" '(if $all then .entries else ([.entries | group_by(.command_hash)[] | max_by(.id)] | sort_by(.id)) end)
    | .[] | "\(.id) \(.task) \(if .expect == "fail" then "red" else .kind end) exit=\(.exit_code)\(if .stale then " STALE" else "" end) \(.command | .[0:70])"' "$IDX"
  exit 0
fi
if [ "$SUB" = "summary" ]; then
  jq -r '[.entries | map(select(.expect != "fail")) | group_by(.command_hash)[] | max_by(.id)] as $l
    | "runs \(.entries|length) · commands \($l|length) · latest failing \([$l[]|select(.exit_code!=0)]|length) · latest stale \([$l[]|select(.stale)]|length) · red runs \([.entries[]|select(.expect == "fail")]|length)",
      ($l[] | select(.exit_code!=0 or .stale) | "  \(.id) \(.task) exit=\(.exit_code)\(if .stale then " STALE" else "" end) \(.command | .[0:70])")' "$IDX"
  exit 0
fi
if [ "$SUB" = "compact" ]; then
  # Move inline touched_files lists (recorded before manifests existed) into manifests.
  n=0
  for id in $(jq -r '.entries[] | select(.touched_files != null) | .id' "$IDX"); do
    e="$(jq -c --arg id "$id" '.entries[] | select(.id==$id)' "$IDX")"
    t="$(printf '%s' "$e" | jq -r .task)"; num="$(printf '%s' "$id" | sed 's/^E-//')"
    m="$EV/$t/$num-touched.tsv"; mkdir -p "$EV/$t"
    printf '%s' "$e" | jq -r '.touched_files[] | "\(.sha256)\t\(.path)"' | sort -k2 > "$m"
    TMP="$(mktemp)"
    jq --arg id "$id" --arg tm "evidence/$t/$(basename "$m")" --arg th "$(aidlc_hash "$m")" --argjson tc "$(wc -l < "$m" | tr -d ' ')" \
      '.entries |= map(if .id==$id then (del(.touched_files) + {touched_count:$tc, touched_manifest:$tm, touched_hash:$th}) else . end)' "$IDX" > "$TMP" && cat "$TMP" > "$IDX"
    rm -f "$TMP"; n=$((n+1))
  done
  [ $n -gt 0 ] && aidlc_lineage "-" "evidence.compacted: $n entries" "$(aidlc_rel "$IDX")" "$(aidlc_hash "$IDX")"
  echo "compacted $n entr$( [ $n -eq 1 ] && echo y || echo ies) in $(aidlc_rel "$IDX")"
  exit 0
fi
[ "$SUB" = "run" ] || { echo "usage: aidlc-evidence.sh run --task TASK-NNN [...] -- <command>" >&2; exit 64; }
[ -n "$TASK" ] || { echo "aidlc-evidence: --task is required" >&2; exit 64; }
[ $# -gt 0 ] || { echo "aidlc-evidence: no command after --" >&2; exit 64; }
CMD="$*"
# A command that masks its own exit code cannot be evidence: its result is always "passed".
AIDLC_MASK_RE='(;[[:space:]]*(exit|return)[[:space:]]+0[[:space:]]*$|\|\|[[:space:]]*(true|:|exit[[:space:]]+0)[[:space:]]*$|;[[:space:]]*true[[:space:]]*$)'
if printf '%s' "$CMD" | grep -Eq "$AIDLC_MASK_RE"; then
  echo "aidlc-evidence: refused — the command masks its exit code (ends in '; exit 0', '|| true' or similar), so it could never fail. Record the real command." >&2
  exit 64
fi

N=$(( $(jq '.entries | length' "$IDX") + 1 ))
ID="$(printf 'E-%03d' "$N")"
SLUG="$(printf '%s' "$CMD" | tr -cs 'A-Za-z0-9' '-' | cut -c1-40 | sed 's/-*$//')"
mkdir -p "$EV/$TASK"
OUT="$EV/$TASK/$(printf '%03d' "$N")-$SLUG.out"
ERR="$EV/$TASK/$(printf '%03d' "$N")-$SLUG.err"

START="$(aidlc_now)"; T0="$(perl -MTime::HiRes=time -e 'printf "%d", time()*1000' 2>/dev/null || echo 0)"
# pipefail: in `npm test | tail`, the test runner's failure must not be hidden by tail's success.
( cd "$AIDLC_PROJECT" && bash -o pipefail -c "$CMD" ) >"$OUT" 2>"$ERR"
RC=$?
T1="$(perl -MTime::HiRes=time -e 'printf "%d", time()*1000' 2>/dev/null || echo 0)"
END="$(aidlc_now)"

# Touched files and their hashes.
TRACK_REL="$(aidlc_rel "$AIDLC_TRACK")"
# 1. --files  2. the files the task declares in TASKS.md (backticked paths in its block)
# 3. tracked changes vs HEAD plus untracked source-like files (documents and images excluded)
TASKS_MD="$AIDLC_PHASE_DIR/TASKS.md"
if [ -n "$FILES" ]; then
  LIST="$(printf '%s' "$FILES" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | sed '/^$/d')"
  TF_SOURCE="--files"
else
  LIST=""
  if [ -f "$TASKS_MD" ]; then
    LIST="$(awk -v t="$TASK" '$0 ~ t"([^0-9]|$)" {f=1; next} f && /TASK-[0-9]+/ {exit} f' "$TASKS_MD" \
      | grep -Eo '`[^` ]+\.[A-Za-z0-9]+`' | tr -d '`' | sort -u | while read -r p; do [ -e "$AIDLC_PROJECT/$p" ] && echo "$p"; done)"
    TF_SOURCE="TASKS.md"
  fi
  if [ -z "$LIST" ]; then
    LIST="$( (cd "$AIDLC_PROJECT" && { git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null \
            | grep -Eiv '(\.(docx?|pptx?|xlsx?|pdf|png|jpe?g|gif|svg|zip)$|(^|/)~\$)'; }) \
            | grep -v "^$TRACK_REL/" | sort -u)"
    TF_SOURCE="git changes"
  fi
fi
# The touched-file list lives in a manifest beside the log (one "sha256<TAB>path" line per file), not in
# the index: the index stays one small line per run however many files a run touches.
MAN="$EV/$TASK/$(printf '%03d' "$N")-touched.tsv"
: > "$MAN"
OLDIFS="$IFS"; IFS='
'
for f in $LIST; do printf '%s\t%s\n' "$(aidlc_hash "$AIDLC_PROJECT/$f")" "$f" >> "$MAN"; done
IFS="$OLDIFS"
sort -k2 "$MAN" -o "$MAN"
TOUCHED_COUNT="$(wc -l < "$MAN" | tr -d ' ')"
TOUCHED_HASH="$(aidlc_hash "$MAN")"

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
   --arg cmd "$CMD" --arg cmdh "$(printf '%s' "$CMD" | aidlc_sha256 | cut -c1-16)" --arg cwd "$(aidlc_rel "$AIDLC_PROJECT")" \
   --arg start "$START" --arg end "$END" --argjson dur "$((T1 - T0))" --argjson rc "$RC" \
   --arg out "evidence/$TASK/$(basename "$OUT")" --arg err "evidence/$TASK/$(basename "$ERR")" \
   --arg outh "$(aidlc_hash "$OUT")" --arg errh "$(aidlc_hash "$ERR")" \
   --arg rep "$REPORT_REL" --arg reph "$REPORT_HASH" --argjson tc "$TOUCHED_COUNT" --arg tm "evidence/$TASK/$(basename "$MAN")" --arg th "$TOUCHED_HASH" \
   --arg model "${AIDLC_MODEL:-unknown}" --arg sdlc "$AIDLC_SDLC_VERSION" --argjson red "$RED" \
   '.entries += [{id:$id, task:$task, acs:$acs, kind:$kind, suite:$suite, command:$cmd, command_hash:$cmdh, cwd:$cwd,
      started_at:$start, finished_at:$end, duration_ms:$dur, exit_code:$rc,
      stdout_path:$out, stdout_sha256:$outh, stderr_path:$err, stderr_sha256:$errh,
      report_path:(if $rep=="" then null else $rep end), report_sha256:(if $reph=="" then null else $reph end),
      touched_count:$tc, touched_manifest:$tm, touched_hash:$th, stale:false, model:$model, sdlc:$sdlc}
      + (if $red then {expect:"fail"} else {} end)]' "$IDX" > "$TMP" && cat "$TMP" > "$IDX"
rm -f "$TMP"

aidlc_lineage "$ID" "evidence.recorded: $TASK $( $RED && echo red || echo "$KIND") exit=$RC" "$(aidlc_rel "$IDX")" "$(aidlc_hash "$IDX")"

# Show the agent what happened, briefly.
tail -n 25 "$OUT"
[ -s "$ERR" ] && { echo "--- stderr (last 15 lines)"; tail -n 15 "$ERR"; }
echo "AIDLC EVIDENCE $ID recorded for $TASK: exit $RC, $TOUCHED_COUNT touched file(s) from $TF_SOURCE, log $(aidlc_rel "$OUT")"
if $RED; then
  if [ "$RC" != "0" ]; then echo "AIDLC RED confirmed for $TASK: the test fails before the change. Now make it pass."; exit 0; fi
  echo "AIDLC RED not shown for $TASK: the test passed before the change, so it proves nothing. Write a test that fails first." >&2
  exit 3
fi
exit $RC
