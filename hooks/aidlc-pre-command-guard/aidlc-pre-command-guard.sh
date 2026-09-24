#!/bin/bash
# aidlc-pre-command-guard — runs before every shell command.
# Blocks destructive commands unless the phase plan permits them and no gate is open,
# and blocks shell edits to the hook machinery or the decision log.
AIDLC_HOOK_NAME="aidlc-pre-command-guard"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/_lib/track-parse.sh"
aidlc_require_jq
aidlc_read_input
aidlc_load_state

CMD="$(aidlc_field .command)"
[ -z "$CMD" ] && exit 0
aidlc_active || exit 0

WRITE_OPS='(>|>>|sed[[:space:]]+-i|perl[[:space:]]+-[a-z]*i|(^|[;&|[:space:]])(rm|mv|cp|tee|chmod|chown|ln|truncate|install)[[:space:]])'

# C03: shell edits to hooks, hook config or the install record.
if printf '%s' "$CMD" | grep -Eq '(\.claude|\.sdlc|\.cursor|\.github)/(hooks|settings(\.local)?\.json|hooks\.json)|sdlc-central\.json' \
   && printf '%s' "$CMD" | grep -Eq "$WRITE_OPS"; then
  aidlc_block C03 "command modifies the hook machinery" "ask a human to run setup/update.sh if the hooks need to change"
fi

# C04: shell writes to the decision log bypass the approval guard.
if printf '%s' "$CMD" | grep -Eq 'human-decisions\.md' && printf '%s' "$CMD" | grep -Eq "$WRITE_OPS"; then
  aidlc_block C04 "command writes human-decisions.md directly" "decisions are recorded only by aidlc-human-approval-guard"
fi

DESTRUCTIVE=""
check() { printf '%s' "$CMD" | grep -Eiq "$1" && DESTRUCTIVE="$2"; }
check '(^|[;&|[:space:]])rm[[:space:]]+(-[a-zA-Z]*[rR]|--recursive)' "rm -r"
check '(^|[;&|[:space:]])git[[:space:]]+push([[:space:]].*)?[[:space:]](--force|-f|--force-with-lease)([[:space:]=]|$)' "git push --force"
check '(^|[;&|[:space:]])git[[:space:]]+push([[:space:]].*)?[[:space:]](main|master|release/[^[:space:]]*)([[:space:]]|$)' "git push to a protected branch"
check '(^|[;&|[:space:]])git[[:space:]]+reset[[:space:]]+--hard' "git reset --hard"
check '(^|[;&|[:space:]])git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f' "git clean -f"
check '(^|[;&|[:space:]])kubectl[[:space:]]+(apply|delete|replace|patch|scale|drain|rollout[[:space:]]+undo)' "kubectl mutation"
check '(^|[;&|[:space:]])(terraform|tofu)[[:space:]]+(apply|destroy|import|state[[:space:]]+rm)' "terraform apply/destroy"
check '(^|[;&|[:space:]])helm[[:space:]]+(install|upgrade|uninstall|delete|rollback)' "helm release change"
check '(^|[;&|[:space:]])airflow[[:space:]]+(dags[[:space:]]+(delete|backfill|trigger)|db[[:space:]]+(reset|clean))' "destructive airflow command"
check '(drop|truncate)[[:space:]]+(table|database|schema)' "DROP/TRUNCATE"
check '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh' "pipe download to shell"
check 'aws[[:space:]]+s3[[:space:]]+(rb|rm[[:space:]].*--recursive)' "aws s3 delete"

# Plain `git push` on a protected current branch.
if [ -z "$DESTRUCTIVE" ] && printf '%s' "$CMD" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+push([[:space:]]|$)'; then
  BR="$(git -C "$AIDLC_PROJECT" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  case "$BR" in main|master|release/*) DESTRUCTIVE="git push while on $BR" ;; esac
fi

[ -z "$DESTRUCTIVE" ] && exit 0

# Allowed only when PLAN.md lists it under "## Permitted destructive commands" and no gate is open.
PLAN="$AIDLC_PHASE_DIR/PLAN.md"
if [ "$AIDLC_GATE" = "none" ] && [ -f "$PLAN" ]; then
  TRIMMED="$(printf '%s' "$CMD" | sed 's/^[[:space:]]*//')"
  ALLOWED="$(awk '/^## Permitted destructive commands/{f=1;next} f&&/^## /{exit} f' "$PLAN" \
    | sed -n 's/^[[:space:]]*[-*][[:space:]]*`\{0,1\}\([^`]*\)`\{0,1\}[[:space:]]*$/\1/p')"
  OLDIFS="$IFS"; IFS='
'
  for prefix in $ALLOWED; do
    [ -z "$prefix" ] && continue
    case "$TRIMMED" in "$prefix"*) IFS="$OLDIFS"; aidlc_log_guardrail C00 "permitted by PLAN.md: $prefix"; exit 0 ;; esac
  done
  IFS="$OLDIFS"
fi

if [ "$AIDLC_GATE" != "none" ]; then
  aidlc_block C02 "$DESTRUCTIVE while gate $AIDLC_GATE is open" "record the decision for $AIDLC_GATE first"
fi
aidlc_block C01 "destructive command ($DESTRUCTIVE)" \
  "list the exact command under '## Permitted destructive commands' in PLAN.md and get the plan approved, or run it yourself outside the agent"
