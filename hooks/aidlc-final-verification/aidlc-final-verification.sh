#!/bin/bash
# aidlc-final-verification — no release-ready claim without the evidence behind it.
# Events:
#   stop    : the agent's last message claims the work is release-ready
#   command : a release command (git tag, deploy, release, publish) is about to run
# Blocks (tier 2 and 3 only):
#   F01 no verification   : VERIFICATION.md missing, or has FAIL rows
#   F02 open review findings : REVIEW.md missing, or lists an open CRITICAL or HIGH finding
#   F03 scorecard missing or blocked : SCORECARD.md missing or not "## GOVERNANCE APPROVED"
#   F04 stale evidence    : evidence/index.json marks an entry stale
AIDLC_HOOK_NAME="aidlc-final-verification"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
aidlc_require_jq
aidlc_read_input
aidlc_load_state
aidlc_active || exit 0
[ "$(aidlc_field .stop_hook_active)" = "true" ] && exit 0
[ "$AIDLC_PHASE" = "none" ] && exit 0
[ "$(aidlc_tier)" = "1" ] && exit 0

TOOL="$(aidlc_field .tool)"
TRIGGER=""
case "$TOOL" in
  command)
    CMD="$(aidlc_field .command)"
    if printf '%s' "$CMD" | grep -Eiq '(^|[;&|[:space:]])(git[[:space:]]+tag|npm[[:space:]]+publish|gh[[:space:]]+release[[:space:]]+create|(make|npm[[:space:]]+run|yarn|pnpm)[[:space:]]+(deploy|release)|[a-z_./-]*deploy[a-z_.-]*\.sh|kubectl[[:space:]]+rollout|helm[[:space:]]+upgrade)'; then
      TRIGGER="release command: $(printf '%s' "$CMD" | cut -c1-60)"
    fi ;;
  stop)
    MSG="$(aidlc_field .last_message)"
    TP="$(aidlc_field .transcript_path)"
    if [ -z "$MSG" ] && [ -n "$TP" ] && [ -f "$TP" ]; then
      MSG="$(tail -n 40 "$TP" | jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text' 2>/dev/null | tail -c 4000)"
    fi
    if printf '%s' "$MSG" | grep -Eiq "(ready (for|to) (release|ship|production|go live|deploy)|release[- ]ready|production[- ]ready|safe to (release|ship|deploy)|ready to merge and release)"; then
      TRIGGER="release-ready claim"
    fi ;;
esac
[ -z "$TRIGGER" ] && exit 0

D="$AIDLC_PHASE_DIR"
V="$D/VERIFICATION.md"; R="$D/REVIEW.md"; S="$D/SCORECARD.md"; E="$D/evidence/index.json"
if [ ! -f "$V" ]; then aidlc_block F01 "$TRIGGER without VERIFICATION.md for $AIDLC_PHASE" "run the verification step"; fi
if grep -Eq '\|[[:space:]]*FAIL[[:space:]]*\|' "$V"; then aidlc_block F01 "$TRIGGER while VERIFICATION.md has FAIL rows" "fix and re-verify the failing criteria"; fi
if [ ! -f "$R" ]; then aidlc_block F02 "$TRIGGER without REVIEW.md" "run the review step"; fi
if grep -Ei '(CRITICAL|HIGH)' "$R" | grep -Eiq '(\|[[:space:]]*open[[:space:]]*\||status:[[:space:]]*open)'; then
  aidlc_block F02 "$TRIGGER with open CRITICAL/HIGH review findings" "resolve them with review-fix"
fi
if [ ! -f "$S" ] || ! grep -q '^## GOVERNANCE APPROVED' "$S"; then
  aidlc_block F03 "$TRIGGER without an approved governance scorecard" "run governance-scorecard and resolve the blocked dimensions"
fi
if [ -f "$E" ] && jq -e '[.entries[]? | select(.stale == true)] | length > 0' "$E" >/dev/null 2>&1; then
  aidlc_block F04 "$TRIGGER with stale evidence" "re-run the verifier so evidence post-dates the last source change"
fi
exit 0
