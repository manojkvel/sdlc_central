#!/bin/bash
# ------------------------------------------------------------------
# aidlc-verify — generate VERIFICATION.md (or UAT.md / CONTRACT_EVIDENCE.md) from recorded evidence.
# ------------------------------------------------------------------
# Usage:
#   aidlc-verify.sh [--mode verify|uat|contract] [--phase NN-slug] [--rerun "<command>"] [--no-rerun "<reason>"] [--force]
#
# For every AC and SC in SPEC.md it finds the evidence that covers it (an entry's --ac list,
# or the task block in TASKS.md that names the criterion) and decides PASS or FAIL:
#   PASS  at least one valid, fresh run exits 0, and the latest run of every covering command exits 0
#   FAIL  no evidence · log missing or altered · evidence stale (touched files changed since) · last run failed
# It re-runs the suite once (--rerun, else unit.yaml verify_command, else the latest --suite entry)
# and fails if the fresh result disagrees with the recorded one. Stale flags are written back
# to evidence/index.json for the final-verification hook.
# The output file is sealed: its first line carries the sha256 of the rest, which the hygiene
# hook checks (H05), so a hand edit is detected.
# Exit 0 = "## VERIFICATION COMPLETE", 2 = "## VERIFICATION FAILED".
# Tier 1 phases skip the file (evidence is still recorded) unless --force.
# ------------------------------------------------------------------
AIDLC_HOOK_NAME="aidlc-verify"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
aidlc_require_jq
AIDLC_INPUT='{}'

MODE="verify"; PHASE_ARG=""; RERUN=""; NORERUN=""; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --phase) PHASE_ARG="$2"; shift 2 ;;
    --rerun) RERUN="$2"; shift 2 ;;
    --no-rerun) NORERUN="${2:-no reason given}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    *) shift ;;
  esac
done
case "$MODE" in verify) OUTNAME="VERIFICATION.md" ;; uat) OUTNAME="UAT.md" ;; contract) OUTNAME="CONTRACT_EVIDENCE.md" ;;
  *) echo "aidlc-verify: unknown mode $MODE" >&2; exit 64 ;; esac

aidlc_load_state
aidlc_active || { echo "aidlc-verify: no track root" >&2; exit 1; }
[ -n "$PHASE_ARG" ] && { AIDLC_PHASE="$PHASE_ARG"; AIDLC_PHASE_DIR="$AIDLC_TRACK/phases/$PHASE_ARG"; }
D="$AIDLC_PHASE_DIR"
[ -d "$D" ] || { echo "aidlc-verify: no phase directory $AIDLC_PHASE" >&2; exit 1; }
TIER="$(aidlc_tier)"
if [ "$TIER" = "1" ] && [ "$MODE" = "verify" ] && [ $FORCE -eq 0 ]; then
  echo "aidlc-verify: tier 1 phase $AIDLC_PHASE — VERIFICATION.md not required; evidence is still recorded in evidence/index.json."
  exit 0
fi

SPEC="$D/SPEC.md"; TASKS="$D/TASKS.md"; IDX="$D/evidence/index.json"; OUT="$D/$OUTNAME"
[ -f "$SPEC" ] || { echo "aidlc-verify: SPEC.md missing in $AIDLC_PHASE" >&2; exit 1; }
[ -f "$IDX" ] || echo '{"version":1,"entries":[]}' > /dev/null

case "$MODE" in
  verify)   KINDS='["test","build","lint","suite"]' ;;
  uat)      KINDS='["uat"]' ;;
  contract) KINDS='["contract"]' ;;
esac

# ---- 1. freshness and integrity of every entry --------------------------------------------
ENTRIES='[]'
if [ -f "$IDX" ]; then
  ENTRIES="$(jq -c --argjson k "$KINDS" '[.entries[] | select(.kind as $x | $k | index($x))]' "$IDX")"
fi
STATUS_JSON='{}'
STALE_IDS=""
for row in $(printf '%s' "$ENTRIES" | jq -r '.[] | @base64'); do
  e="$(printf '%s' "$row" | base64 --decode)"
  id="$(printf '%s' "$e" | jq -r .id)"
  state="ok"
  outp="$D/$(printf '%s' "$e" | jq -r .stdout_path)"
  if [ ! -f "$outp" ]; then state="log missing"
  elif [ "$(aidlc_hash "$outp")" != "$(printf '%s' "$e" | jq -r .stdout_sha256)" ]; then state="log altered"
  else
    for tf in $(printf '%s' "$e" | jq -r '.touched_files[] | @base64'); do
      p="$(printf '%s' "$tf" | base64 --decode | jq -r .path)"; h="$(printf '%s' "$tf" | base64 --decode | jq -r .sha256)"
      if [ "$(aidlc_hash "$AIDLC_PROJECT/$p")" != "$h" ]; then state="stale: $p changed"; STALE_IDS="$STALE_IDS $id"; break; fi
    done
  fi
  STATUS_JSON="$(printf '%s' "$STATUS_JSON" | jq -c --arg id "$id" --arg s "$state" '. + {($id): $s}')"
done

if [ -f "$IDX" ]; then
  TMP="$(mktemp)"
  jq --arg ids "$STALE_IDS" '($ids | split(" ") | map(select(. != ""))) as $s | .entries |= map(.stale = ((.id as $i | $s | index($i)) != null))' "$IDX" > "$TMP" && cat "$TMP" > "$IDX"
  rm -f "$TMP"
fi

# ---- 2. criteria → covering entries ---------------------------------------------------------
tasks_for() {  # tasks whose block in TASKS.md names the criterion
  [ -f "$TASKS" ] || return 0
  awk -v c="$1" '
    /TASK-[0-9]+/ && match($0, /TASK-[0-9]+/) { cur = substr($0, RSTART, RLENGTH) }
    cur != "" && $0 ~ ("(^|[^A-Za-z0-9-])" c "([^0-9]|$)") { print cur }
  ' "$TASKS" | sort -u
}

CRITERIA="$(grep -Eo '(AC|SC)-[0-9]+' "$SPEC" | awk '!seen[$0]++')"
ROWS=""; NPASS=0; NFAIL=0
for c in $CRITERIA; do
  desc="$(grep -E "(^|[^A-Za-z0-9-])$c([^0-9]|$)" "$SPEC" | head -1 | sed -E "s/.*$c[^A-Za-z0-9]*//" | tr '|' '/' | cut -c1-70)"
  TASKLIST="$(tasks_for "$c" | tr '\n' ' ')"
  # Fail closed: any error computing coverage is treated as "no evidence", never as a pass.
  COVER="$(printf '%s' "$ENTRIES" | jq -c --arg c "$c" --arg t " $TASKLIST " \
      '[.[] | . as $e | select(((($e.acs // []) | index($c)) != null) or ($t | contains(" " + ($e.task // "") + " ")))]' 2>/dev/null)"
  n="$(printf '%s' "$COVER" | jq 'length' 2>/dev/null)"
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" = "0" ]; then
    ROWS="$ROWS| $c | $desc | FAIL | — | no evidence covers this criterion |
"; NFAIL=$((NFAIL+1)); continue
  fi
  # latest entry per command
  LATEST="$(printf '%s' "$COVER" | jq -c 'group_by(.command_hash) | map(max_by(.id))')"
  REFS="$(printf '%s' "$LATEST" | jq -r '[.[] | "\(.id) (\(.task), exit \(.exit_code))"] | join(", ")')"
  VERDICT="PASS"; NOTE=""; CHECKED=0
  for id in $(printf '%s' "$LATEST" | jq -r '.[].id' 2>/dev/null); do
    CHECKED=$((CHECKED+1))
    st="$(printf '%s' "$STATUS_JSON" | jq -r --arg id "$id" '.[$id]')"
    rc="$(printf '%s' "$LATEST" | jq -r --arg id "$id" '.[] | select(.id==$id) | .exit_code')"
    if [ "$st" != "ok" ]; then VERDICT="FAIL"; NOTE="$NOTE$id $st; "
    elif [ "$rc" != "0" ]; then VERDICT="FAIL"; NOTE="$NOTE$id last run exited $rc; "; fi
  done
  [ $CHECKED -eq 0 ] && { VERDICT="FAIL"; NOTE="evidence could not be evaluated"; }
  [ "$VERDICT" = "PASS" ] && NOTE="fresh, exit 0"
  ROWS="$ROWS| $c | $desc | $VERDICT | $REFS | ${NOTE%; } |
"
  if [ "$VERDICT" = "PASS" ]; then NPASS=$((NPASS+1)); else NFAIL=$((NFAIL+1)); fi
done
NCRIT=$((NPASS + NFAIL))
[ $NCRIT -eq 0 ] && { ROWS="| — | SPEC.md names no AC or SC | FAIL | — | nothing to verify |
"; NFAIL=1; }

# ---- 3. re-execution -------------------------------------------------------------------------
RERUN_ROW=""; RERUN_OK=1
if [ "$MODE" = "verify" ]; then
  if [ -z "$RERUN" ] && [ -f "$D/unit.yaml" ]; then
    RERUN="$(grep -E '^verify_command:' "$D/unit.yaml" | head -1 | sed -E 's/^verify_command:[[:space:]]*//; s/^"(.*)"$/\1/')"
  fi
  RECORDED_RC=""
  if [ -z "$RERUN" ]; then
    RERUN="$(printf '%s' "$ENTRIES" | jq -r '[.[] | select(.suite == true)] | max_by(.id) | .command // empty')"
  fi
  if [ -n "$RERUN" ]; then
    RECORDED_RC="$(printf '%s' "$ENTRIES" | jq -r --arg c "$RERUN" '[.[] | select(.command == $c)] | max_by(.id) | .exit_code // empty')"
  fi
  if [ -n "$NORERUN" ]; then
    RERUN_ROW="| RERUN | re-execution waived | WAIVED | — | $(printf '%s' "$NORERUN" | tr '|' '/' | cut -c1-80) |"
  elif [ -z "$RERUN" ]; then
    RERUN_ROW="| RERUN | re-execution of the suite | FAIL | — | no suite command: set verify_command in unit.yaml or record one run with --suite |"
    RERUN_OK=0
  else
    mkdir -p "$D/evidence/_verify"
    RLOG="$D/evidence/_verify/rerun-$(date -u +%Y%m%dT%H%M%SZ).out"
    ( cd "$AIDLC_PROJECT" && bash -c "$RERUN" ) >"$RLOG" 2>&1
    FRESH=$?
    if [ "$FRESH" != "0" ]; then
      RERUN_ROW="| RERUN | \`$(printf '%s' "$RERUN" | cut -c1-50)\` | FAIL | $(aidlc_rel "$RLOG") | fresh run exited $FRESH (recorded ${RECORDED_RC:-none}) |"; RERUN_OK=0
    elif [ -n "$RECORDED_RC" ] && [ "$RECORDED_RC" != "0" ]; then
      RERUN_ROW="| RERUN | \`$(printf '%s' "$RERUN" | cut -c1-50)\` | FAIL | $(aidlc_rel "$RLOG") | fresh run passed but the recorded run exited $RECORDED_RC; record a passing run |"; RERUN_OK=0
    else
      RERUN_ROW="| RERUN | \`$(printf '%s' "$RERUN" | cut -c1-50)\` | PASS | $(aidlc_rel "$RLOG") | fresh run agrees with recorded evidence |"
    fi
    aidlc_lineage "-" "evidence.reexecuted: exit=$FRESH" "$(aidlc_rel "$RLOG")" "$(aidlc_hash "$RLOG")"
  fi
fi

# ---- 4. write the sealed file ------------------------------------------------------------------
if [ $NFAIL -eq 0 ] && [ $RERUN_OK -eq 1 ]; then RESULT="COMPLETE"; else RESULT="FAILED"; fi
NSTALE="$(printf '%s' "$STALE_IDS" | wc -w | tr -d ' ')"
CLAIMS="none"
[ -f "$D/SUMMARY.md" ] && CLAIMS="$(sed '/^#/d; /^[[:space:]]*$/d' "$D/SUMMARY.md" | head -3 | tr '\n' ' ' | cut -c1-240)"
BODY="$(mktemp)"
{
  echo "# ${OUTNAME%.md} — $AIDLC_PHASE"
  echo ""
  echo "## Summary"
  echo "- **Result:** $RESULT"
  echo "- **Criteria:** $NPASS pass, $NFAIL fail, of $NCRIT"
  echo "- **Stale evidence entries:** $NSTALE"
  echo "- **Evidence index:** \`evidence/index.json\` sha256:$(aidlc_hash "$IDX")"
  echo "- **Spec:** \`SPEC.md\` sha256:$(aidlc_hash "$SPEC")"
  echo "- **Mode:** $MODE · **Tier:** $TIER · **Generated:** $(aidlc_now)"
  echo ""
  echo "Claims under review (from SUMMARY.md, not evidence): $CLAIMS"
  echo ""
  echo "## Criteria"
  echo ""
  echo "| Criterion | Description | Result | Evidence | Notes |"
  echo "| --- | --- | --- | --- | --- |"
  printf '%s' "$ROWS"
  [ -n "$RERUN_ROW" ] && echo "$RERUN_ROW"
  echo ""
  echo "## VERIFICATION $RESULT"
} > "$BODY"
SEAL="$(shasum -a 256 "$BODY" | cut -c1-64)"
{ echo "<!-- generated-by: aidlc-evidence-verifier sha256:$SEAL -->"; cat "$BODY"; } > "$OUT"
rm -f "$BODY"

aidlc_lineage "-" "evidence.verified: $OUTNAME $RESULT" "$(aidlc_rel "$OUT")" "$(aidlc_hash "$OUT")"
cat "$OUT" | sed -n '2,$p' | sed -n '/## Summary/,/## Criteria/p' | sed '$d'
echo "Wrote $(aidlc_rel "$OUT"): VERIFICATION $RESULT"
[ "$RESULT" = "COMPLETE" ] && exit 0 || exit 2
