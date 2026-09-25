#!/bin/bash
# ------------------------------------------------------------------
# aidlc-decide — the decision bot's entry point: record a gate decision with an authenticated identity.
# ------------------------------------------------------------------
# Usage (normally from the aidlc-decision GitHub Actions workflow, where GitHub authenticates the actor):
#   aidlc-decide.sh --decision "<decision string>" --actor <login or SSO id> --identity github|sso
#                   [--expect-gate <gate>] [--role <role>] [--commit] [--push]
# It never bypasses the guard: the decision goes through aidlc-human-approval-guard exactly as a typed
# reply would, with the identity source recorded as github or sso instead of asserted. Stakeholder
# authorisation (A06) applies because the identity is authenticated.
# --expect-gate refuses to act if the open gate changed since the person decided (no racing).
# --commit commits the decision record, lineage, state, risks and unit changes; --push pushes them.
# Exit codes: the guard's (0 recorded, 2 rejected); 3 gate mismatch or no open gate; 4 git failure.
# ------------------------------------------------------------------
AIDLC_HOOK_NAME="aidlc-decide"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/_lib/track-parse.sh"
aidlc_require_jq
AIDLC_INPUT='{}'
DECISION=""; ACTOR=""; IDS=""; EXPECT=""; ROLE=""; COMMIT=0; PUSH=0
while [ $# -gt 0 ]; do case "$1" in
  --decision) DECISION="$2"; shift 2 ;; --actor) ACTOR="$2"; shift 2 ;; --identity) IDS="$2"; shift 2 ;;
  --expect-gate) EXPECT="$2"; shift 2 ;; --role) ROLE="$2"; shift 2 ;; --commit) COMMIT=1; shift ;; --push) PUSH=1; COMMIT=1; shift ;;
  *) shift ;; esac; done
[ -n "$DECISION" ] && [ -n "$ACTOR" ] || { echo "usage: aidlc-decide.sh --decision '<string>' --actor <id> --identity github|sso" >&2; exit 64; }
case "$IDS" in github|sso) ;; *) echo "aidlc-decide: --identity must be github or sso (authenticated sources only)" >&2; exit 64 ;; esac
aidlc_load_state
aidlc_active || { echo "aidlc-decide: no track root" >&2; exit 3; }
[ "$AIDLC_GATE" = "none" ] && { echo "aidlc-decide: no gate is open; nothing to decide" >&2; exit 3; }
[ -n "$EXPECT" ] && [ "$EXPECT" != "$AIDLC_GATE" ] && { echo "aidlc-decide: the open gate is $AIDLC_GATE, not $EXPECT; refresh and decide again" >&2; exit 3; }
ARGS="--as $ACTOR --identity $IDS"
PAYLOAD="$(jq -nc --arg p "$DECISION" '{tool:"prompt", prompt:$p}')"
if [ -n "$ROLE" ]; then OUT="$(printf '%s' "$PAYLOAD" | bash "$HERE/aidlc-human-approval-guard/aidlc-human-approval-guard.sh" --as "$ACTOR" --identity "$IDS" --role "$ROLE" 2>&1)"; RC=$?
else OUT="$(printf '%s' "$PAYLOAD" | bash "$HERE/aidlc-human-approval-guard/aidlc-human-approval-guard.sh" --as "$ACTOR" --identity "$IDS" 2>&1)"; RC=$?; fi
printf '%s\n' "$OUT"
[ $RC -ne 0 ] && exit $RC
printf '%s' "$OUT" | grep -q '^DECISION RECEIPT' || { echo "aidlc-decide: the reply was not a decision for gate $AIDLC_GATE" >&2; exit 2; }
if [ $COMMIT -eq 1 ]; then
  HD="$(printf '%s' "$OUT" | sed -n 's/^DECISION RECEIPT \(HD-[0-9]*\).*/\1/p')"
  cd "$AIDLC_PROJECT" || exit 4
  git add -- "$(aidlc_rel "$AIDLC_TRACK")" 2>/dev/null || exit 4
  git -c user.name="aidlc-decision-bot" -c user.email="aidlc-decision-bot@users.noreply.github.com" \
    commit -q -m "aidlc: $HD $AIDLC_GATE — $(printf '%s' "$DECISION" | cut -c1-60) (by $ACTOR via $IDS)" || exit 4
  echo "Committed $(git rev-parse --short HEAD)"
  [ $PUSH -eq 1 ] && { git push -q || exit 4; echo "Pushed"; }
fi
exit 0
