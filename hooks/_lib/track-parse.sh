#!/bin/bash
# ------------------------------------------------------------------
# AIDLC hook library — sourced by every hook in hooks/<name>/<name>.sh
# ------------------------------------------------------------------
# Hook contract (see docs/aidlc/hooks.md):
#   stdin : JSON {event, tool, path | command | prompt, cwd, transcript_path, stop_hook_active}
#   exit 0: allow            exit 2: block, one-line reason on stderr
#   exit 1: hook failure — the wrapper treats it as allow-with-warning, never a silent block
# Constraints: bash 3.2, no network, no model calls, jq + shasum only.
# ------------------------------------------------------------------

AIDLC_SDLC_VERSION="${AIDLC_SDLC_VERSION:-2.0.0-alpha}"
AIDLC_INPUT=""
AIDLC_HOOK_NAME="${AIDLC_HOOK_NAME:-aidlc-hook}"

aidlc_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "AIDLC WARN $AIDLC_HOOK_NAME: jq not found; hook skipped (install jq to enforce)." >&2
    exit 1
  fi
}

# Read the whole stdin payload once.
aidlc_read_input() {
  AIDLC_INPUT="$(cat)"
  [ -z "$AIDLC_INPUT" ] && AIDLC_INPUT='{}'
}

# aidlc_field <jq-path>  e.g. aidlc_field .path
aidlc_field() {
  printf '%s' "$AIDLC_INPUT" | jq -r "$1 // empty" 2>/dev/null
}

aidlc_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Project directory: explicit env, then Claude Code's env, then the payload cwd, then pwd.
aidlc_project_dir() {
  if [ -n "$AIDLC_PROJECT_DIR" ]; then echo "$AIDLC_PROJECT_DIR"; return; fi
  if [ -n "$CLAUDE_PROJECT_DIR" ]; then echo "$CLAUDE_PROJECT_DIR"; return; fi
  local c; c="$(aidlc_field .cwd)"
  if [ -n "$c" ] && [ -d "$c" ]; then echo "$c"; return; fi
  pwd
}

# First agent config file that exists.
aidlc_config_file() {
  local p="$1" d
  for d in .claude .sdlc .cursor .github; do
    if [ -f "$p/$d/sdlc-central.json" ]; then echo "$p/$d/sdlc-central.json"; return; fi
  done
}

aidlc_agent_dir_name() {
  local cfg; cfg="$(aidlc_config_file "$1")"
  if [ -n "$cfg" ]; then basename "$(dirname "$cfg")"; else echo ".claude"; fi
}

# Absolute path of the track root (default .track, overridable via track_root).
aidlc_track_root() {
  local p="$1" root cfg
  if [ -n "$AIDLC_TRACK_ROOT" ]; then root="$AIDLC_TRACK_ROOT"
  else
    cfg="$(aidlc_config_file "$p")"
    [ -n "$cfg" ] && root="$(jq -r '.track_root // empty' "$cfg" 2>/dev/null)"
    [ -z "$root" ] && root=".track"
  fi
  case "$root" in /*) echo "$root" ;; *) echo "$p/$root" ;; esac
}

# resume_field <state.md> <KEY>  → value from the AIDLC_RESUME block
resume_field() {
  local f="$1" key="$2"
  [ -f "$f" ] || return 0
  awk -v k="$key" '
    /^## AIDLC_RESUME/ {inb=1; next}
    inb && /^## / {exit}
    inb && index($0, k ": ") == 1 { sub("^" k ": *", ""); sub(/[ \t]+$/, ""); print; exit }
  ' "$f"
}

# set_resume_field <state.md> <KEY> <value>  (adds the key at the end of the block if missing)
set_resume_field() {
  local f="$1" key="$2" val="$3" tmp
  tmp="$(mktemp)"
  awk -v k="$key" -v v="$val" '
    /^## AIDLC_RESUME/ {print; inb=1; next}
    inb && /^## / { if (!done) print k ": " v; done=1; inb=0 }
    inb && index($0, k ": ") == 1 { print k ": " v; done=1; next }
    inb && /^[ \t]*$/ && !done { print k ": " v; done=1 }
    {print}
    END { if (inb && !done) print k ": " v }
  ' "$f" > "$tmp" && cat "$tmp" > "$f"
  rm -f "$tmp"
}

# Load the resume block into shell variables.
aidlc_load_state() {
  AIDLC_PROJECT="$(aidlc_project_dir)"
  AIDLC_TRACK="$(aidlc_track_root "$AIDLC_PROJECT")"
  AIDLC_STATE="$AIDLC_TRACK/state.md"
  AIDLC_PHASE="$(resume_field "$AIDLC_STATE" CURRENT_PHASE)"
  AIDLC_STAGE="$(resume_field "$AIDLC_STATE" CURRENT_STAGE)"
  AIDLC_GATE="$(resume_field "$AIDLC_STATE" BLOCKED_GATE)"
  AIDLC_GATE_RISK="$(resume_field "$AIDLC_STATE" GATE_RISK)"
  [ -z "$AIDLC_PHASE" ] && AIDLC_PHASE="none"
  [ -z "$AIDLC_GATE" ] && AIDLC_GATE="none"
  AIDLC_PHASE_DIR="$AIDLC_TRACK/phases/$AIDLC_PHASE"
}

# True when the project has adopted AIDLC. Hooks are inert until init-track.sh runs.
aidlc_active() { [ -d "$AIDLC_TRACK" ] && [ -f "$AIDLC_STATE" ]; }

# Tier of the current phase: unit.yaml, then config tier_default, then profile floor, then 2.
aidlc_tier() {
  local t="" cfg
  if [ -f "$AIDLC_PHASE_DIR/unit.yaml" ]; then
    t="$(grep -E '^tier:' "$AIDLC_PHASE_DIR/unit.yaml" | head -1 | sed 's/^tier:[ ]*//; s/[^0-9].*$//')"
  fi
  if [ -z "$t" ] && [ -f "$AIDLC_PHASE_DIR/unit.md" ] && [ ! -f "$AIDLC_PHASE_DIR/unit.yaml" ]; then t=1; fi
  if [ -z "$t" ]; then
    cfg="$(aidlc_config_file "$AIDLC_PROJECT")"
    [ -n "$cfg" ] && t="$(jq -r '.tier_default // empty' "$cfg" 2>/dev/null)"
  fi
  [ -z "$t" ] && t=2
  echo "$t"
}

aidlc_hash() {
  if [ -f "$1" ]; then shasum -a 256 "$1" | cut -c1-64; else echo "-"; fi
}

# Hash of an artifact as approved. For contracts, the fields the registry maintains after approval
# (status, approved_by_decision, last_test) are excluded, so a status change is not an edit; any
# change to the schema, test command, version, consumers or body still is.
aidlc_artifact_hash() {
  [ -f "$1" ] || { echo "-"; return; }
  case "$1" in
    */contracts/C-*.md) grep -Ev '^(status|approved_by_decision|last_test):' "$1" | shasum -a 256 | cut -c1-64 ;;
    */unit.yaml) grep -Ev '^release_claims_excluded:' "$1" | shasum -a 256 | cut -c1-64 ;;
    *) shasum -a 256 "$1" | cut -c1-64 ;;
  esac
}

# Path relative to the project directory.
aidlc_rel() {
  local p="$1"
  case "$p" in "$AIDLC_PROJECT"/*) echo "${p#$AIDLC_PROJECT/}" ;; *) echo "$p" ;; esac
}

aidlc_abs() {
  local p="$1"
  case "$p" in /*) echo "$p" ;; *) echo "$AIDLC_PROJECT/$p" ;; esac
}

aidlc_log_guardrail() {
  local code="$1" msg="$2"
  [ -d "$AIDLC_TRACK" ] || return 0
  local log="$AIDLC_TRACK/guardrail-log.md"
  if [ ! -f "$log" ]; then
    printf '# Guardrail log\n\n| Timestamp | Hook | Code | Phase | Detail |\n| --- | --- | --- | --- | --- |\n' > "$log"
  fi
  printf '| %s | %s | %s | %s | %s |\n' "$(aidlc_now)" "$AIDLC_HOOK_NAME" "$code" "${AIDLC_PHASE:-none}" "$(printf '%s' "$msg" | tr '|\n' '/ ' | cut -c1-200)" >> "$log"
}

aidlc_lineage() {
  # aidlc_lineage <ref> <family.event: detail> <artifact> <hash>
  [ -d "$AIDLC_TRACK" ] || return 0
  local lf="$AIDLC_TRACK/lineage.md"
  [ -f "$lf" ] || printf '# Lineage\n\n' > "$lf"
  printf '%s | %s | %s | %s | sha256:%s | model=%s | sdlc=%s\n' \
    "$(aidlc_now)" "$1" "$2" "${3:--}" "${4:--}" "${AIDLC_MODEL:-unknown}" "$AIDLC_SDLC_VERSION" >> "$lf"
}

# aidlc_block <code> <reason> <next action>  → logs, prints, exits 2
aidlc_block() {
  local code="$1" reason="$2" next="$3"
  aidlc_log_guardrail "$code" "$reason"
  echo "AIDLC BLOCK $AIDLC_HOOK_NAME $code: $reason. Next: $next" >&2
  exit 2
}

# Protected paths: hook scripts, agent hook config, install tracking file.
aidlc_is_protected_path() {
  local rel="$1"
  case "$rel" in
    .claude/hooks/*|.sdlc/hooks/*|.cursor/hooks/*|.github/hooks/*) return 0 ;;
    .claude/settings.json|.claude/settings.local.json|.cursor/hooks.json) return 0 ;;
    */sdlc-central.json|sdlc-central.json) return 0 ;;
  esac
  return 1
}

aidlc_is_secret_target() {
  local base; base="$(basename "$1")"
  case "$base" in
    .env|.env.*|*.pem|*.key|*.p12|*.pfx|id_rsa|id_rsa*|id_ed25519*|id_ecdsa*|credentials|credentials.*|.npmrc|.pypirc|.netrc) return 0 ;;
  esac
  return 1
}

# Secret patterns as one ERE (used by hygiene and the command guard).
AIDLC_SECRET_RE='AKIA[0-9A-Z]{16}|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----|xox[baprs]-[0-9A-Za-z-]{10,}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{40,}|sk-[A-Za-z0-9]{32,}|sk-ant-[A-Za-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{35}|(api[_-]?key|secret|token|password)[[:space:]]*[:=][[:space:]]*["'\''][A-Za-z0-9/+_=-]{16,}["'\'']'

# Raw context wrappers that must never land in a durable artifact.
AIDLC_WRAPPER_RE='</?(context|system|system-reminder|user_query|assistant|tool_result|function_results)>|BEGIN PROMPT|END PROMPT|<\|im_(start|end)\|>'
