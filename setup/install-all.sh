#!/bin/bash
# ------------------------------------------------------------------
# Install ALL SDLC Central Skills (50 skills + all pipelines)
# ------------------------------------------------------------------
# Run this from your project root:
#   bash /path/to/sdlc_central/setup/install-all.sh [--agent <agent>] [--no-hooks] [--tier-default 1|2|3] [--track-root <path>]
# ------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDLC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$(pwd)"
VERSION="1.0.0"

# --- Parse arguments ---
AGENT="claude-code"
NO_HOOKS=0
TIER_DEFAULT=""
TRACK_ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --agent)
      AGENT="$2"
      shift 2
      ;;
    --agent=*)
      AGENT="${1#*=}"
      shift
      ;;
    --no-hooks)
      NO_HOOKS=1
      shift
      ;;
    --tier-default)
      TIER_DEFAULT="$2"
      shift 2
      ;;
    --tier-default=*)
      TIER_DEFAULT="${1#*=}"
      shift
      ;;
    --track-root)
      TRACK_ROOT="$2"
      shift 2
      ;;
    --track-root=*)
      TRACK_ROOT="${1#*=}"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

echo "╔══════════════════════════════════════════════╗"
echo "║     SDLC Central — Full Installation         ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Installing all 50 skills + all pipelines into: $PROJECT_DIR"
echo "Agent: $AGENT"
echo ""

# All skills
SKILLS=(
  api-contract-analyzer
  approval-workflow-auditor
  auto-triage
  board-sync
  code-ownership-mapper
  cross-repo-standards-enforcer
  decision-log
  dependency-update
  design-review
  doc-gen
  drift-detector
  feature-balance-sheet
  feedback-loop
  gate-briefing
  impact-analysis
  incident-detector
  incident-postmortem-synthesizer
  incident-triager
  license-compliance-audit
  migration-tracker
  onboarding-guide
  perf-review
  pipeline-monitor
  pipeline-orchestrator
  plan-gen plan-check aidlc-evidence-verifier
  plan-merge
  pr-orchestrator
  quality-gate
  regression-check
  release-notes
  release-readiness-checker
  report-trends
  reverse-engineer
  review
  review-fix
  risk-tracker
  rollback-assessor
  scope-tracker
  security-audit
  security-audit-deep
  skill-gap-analyzer
  slo-sla-tracker
  spec-evolve
  spec-fix
  spec-gen
  spec-review
  task-gen
  task-implementer
  tech-debt-audit
  test-gen
  wave-scheduler
)

ALL_ROLES=(product-owner architect developer qa devops-sre tech-lead scrum-master designer)

# --- Install skills via adapter ---
ADAPTER="$SDLC_ROOT/adapters/$AGENT/adapter.sh"

if [ -f "$ADAPTER" ]; then
  echo "Installing skills (via $AGENT adapter)..."
  bash "$ADAPTER" "$SDLC_ROOT" "$PROJECT_DIR" "${SKILLS[@]}"
  INSTALLED=${#SKILLS[@]}
else
  # Fallback: direct copy
  echo "Installing skills..."
  INSTALLED=0
  MISSING=0
  for skill in "${SKILLS[@]}"; do
    mkdir -p "$PROJECT_DIR/.claude/skills/$skill"
    if [ -f "$SDLC_ROOT/skills/$skill/SKILL.md" ]; then
      cp "$SDLC_ROOT/skills/$skill/SKILL.md" "$PROJECT_DIR/.claude/skills/$skill/SKILL.md"
      echo "  ✓ $skill"
      INSTALLED=$((INSTALLED + 1))
    else
      echo "  ✗ $skill (SKILL.md not found)"
      MISSING=$((MISSING + 1))
    fi
  done
fi

# --- Install all pipelines ---
echo ""
echo "Installing pipelines..."

# Determine pipeline location based on agent
case "$AGENT" in
  claude-code)
    PIPELINE_DIR="$PROJECT_DIR/.claude/pipelines"
    ;;
  cursor)
    PIPELINE_DIR="$PROJECT_DIR/.cursor/pipelines"
    ;;
  copilot)
    PIPELINE_DIR="$PROJECT_DIR/.github/pipelines"
    ;;
  *)
    PIPELINE_DIR="$PROJECT_DIR/.sdlc/pipelines"
    ;;
esac

# Install pipeline engine (for claude-code, included in adapter)
if [ "$AGENT" != "claude-code" ]; then
  if [ -f "$SDLC_ROOT/pipelines/_engine/PIPELINE-RUNNER.md" ]; then
    mkdir -p "$PIPELINE_DIR/_engine"
    cp "$SDLC_ROOT/pipelines/_engine/PIPELINE-RUNNER.md" "$PIPELINE_DIR/_engine/PIPELINE-RUNNER.md"
    echo "  ✓ PIPELINE-RUNNER"
  fi
  if [ -f "$SDLC_ROOT/pipelines/_engine/PROGRESS-TEMPLATE.md" ]; then
    mkdir -p "$PIPELINE_DIR/_engine"
    cp "$SDLC_ROOT/pipelines/_engine/PROGRESS-TEMPLATE.md" "$PIPELINE_DIR/_engine/PROGRESS-TEMPLATE.md"
    echo "  ✓ PROGRESS-TEMPLATE"
  fi
fi

for role in "${ALL_ROLES[@]}"; do
  if [ -d "$SDLC_ROOT/pipelines/$role" ]; then
    mkdir -p "$PIPELINE_DIR/$role"
    for pipeline in "$SDLC_ROOT/pipelines/$role"/*.pipeline.yaml; do
      if [ -f "$pipeline" ]; then
        cp "$pipeline" "$PIPELINE_DIR/$role/"
        echo "  ✓ $role/$(basename "$pipeline")"
      fi
    done
  fi
done

# --- Install config (only if not already present) ---
echo ""
echo "Installing config..."

case "$AGENT" in
  claude-code)
    CONFIG_DIR="$PROJECT_DIR/.claude/config"
    ;;
  *)
    CONFIG_DIR="$PROJECT_DIR/.sdlc/config"
    ;;
esac

mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/gate-config.json" ]; then
  cp "$SDLC_ROOT/config/gate-config.json" "$CONFIG_DIR/gate-config.json"
  echo "  ✓ gate-config.json (new)"
else
  echo "  ○ gate-config.json (exists — preserved)"
fi
if [ ! -f "$CONFIG_DIR/balance-sheet-config.json" ]; then
  cp "$SDLC_ROOT/config/balance-sheet-config.json" "$CONFIG_DIR/balance-sheet-config.json"
  echo "  ✓ balance-sheet-config.json (new)"
else
  echo "  ○ balance-sheet-config.json (exists — preserved)"
fi

# --- AIDLC: work-type profiles (preserve existing) ---
if [ ! -f "$CONFIG_DIR/profiles.yaml" ] && [ -f "$SDLC_ROOT/config/profiles.yaml" ]; then
  cp "$SDLC_ROOT/config/profiles.yaml" "$CONFIG_DIR/profiles.yaml"
  echo "  ✓ profiles.yaml"
fi

# --- AIDLC: hooks ---
echo ""
echo "Hooks:"
source "$SDLC_ROOT/adapters/_shared/hooks.sh"
HOOK_LEVEL="$(hook_support_level "$AGENT")"
if [ "$NO_HOOKS" = "1" ]; then
  HOOKS_INSTALLED=false
  HOOK_LEVEL="none"
  echo "  ○ hooks skipped (--no-hooks)"
  emit_tools "$AGENT" "$SDLC_ROOT" "$PROJECT_DIR"
else
  emit_hooks "$AGENT" "$SDLC_ROOT" "$PROJECT_DIR"
  HOOKS_INSTALLED=true
fi
echo "  Hook enforcement on $AGENT: $HOOK_LEVEL. Hooks stay inert until the project has a track root (setup/init-track.sh)."

# --- Write tracking file ---
TRACKING_DIR="$PROJECT_DIR/.sdlc"
mkdir -p "$TRACKING_DIR"
TRACKING_FILE="$TRACKING_DIR/sdlc-central.json"

if [ "$AGENT" = "claude-code" ]; then
  TRACKING_FILE="$PROJECT_DIR/.claude/sdlc-central.json"
fi

# --- AIDLC settings: keep previous values unless a flag overrides them ---
if [ -f "$TRACKING_FILE" ] && command -v jq >/dev/null 2>&1; then
  [ -z "$TRACK_ROOT" ] && TRACK_ROOT="$(jq -r '.track_root // empty' "$TRACKING_FILE" 2>/dev/null)"
  [ -z "$TIER_DEFAULT" ] && TIER_DEFAULT="$(jq -r '.tier_default // empty' "$TRACKING_FILE" 2>/dev/null)"
fi
[ -z "$TRACK_ROOT" ] && TRACK_ROOT=".track"
[ -z "$TIER_DEFAULT" ] && TIER_DEFAULT="2"

cat > "$TRACKING_FILE" << EOF
{
  "version": "$VERSION",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source": "$SDLC_ROOT",
  "agent": "$AGENT",
  "roles": ["all"],
  "skill_count": $INSTALLED,
  "pipelines_installed": true,
  "track_root": "$TRACK_ROOT",
  "tier_default": $TIER_DEFAULT,
  "hooks_installed": $HOOKS_INSTALLED,
  "hook_support_level": "$HOOK_LEVEL"
}
EOF
echo ""
echo "  ✓ sdlc-central.json (tracking file)"

# --- Create agent-specific project file if missing ---
echo ""
case "$AGENT" in
  claude-code)
    if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
      TMPL_DIR="$SDLC_ROOT/adapters/claude-code/templates"
      if [ -f "$TMPL_DIR/CLAUDE.md.base" ]; then
        cp "$TMPL_DIR/CLAUDE.md.base" "$PROJECT_DIR/CLAUDE.md"
      elif [ -f "$SDLC_ROOT/templates/CLAUDE.md.base" ]; then
        cp "$SDLC_ROOT/templates/CLAUDE.md.base" "$PROJECT_DIR/CLAUDE.md"
      fi
      if [ -f "$PROJECT_DIR/CLAUDE.md" ]; then
        echo "Created CLAUDE.md — edit this with your project-specific standards."
      fi
    else
      echo "CLAUDE.md already exists — skipping (check templates/ for reference)."
    fi
    ;;
  *)
    echo "Agent rules installed for $AGENT."
    ;;
esac

# --- Summary ---
echo ""
echo "════════════════════════════════════════════════"
echo "  $INSTALLED skills installed successfully! (agent: $AGENT)"
echo "════════════════════════════════════════════════"
echo ""

case "$AGENT" in
  claude-code)
    echo "Quick start:"
    echo "  claude> /review              # Code review"
    echo "  claude> /spec-gen 'feature'  # Generate spec"
    echo "  claude> /test-gen src/file   # Generate tests"
    echo "  claude> /run-pipeline developer/feature-build specs/NNN/plan.md"
    echo ""
    echo "Tip: Commit .claude/ to git so your team gets these skills too."
    ;;
  cursor)
    echo "Quick start: Open Cursor and ask the agent about any SDLC skill."
    echo "Skills auto-attach based on context. Rules are in .cursor/rules/"
    ;;
  copilot)
    echo "Quick start: Open VS Code with Copilot Chat."
    echo "Instructions are in .github/instructions/ and auto-apply by file type."
    ;;
  windsurf)
    echo "Quick start: Open Windsurf — rules are in .windsurf/rules/"
    ;;
  cline)
    echo "Quick start: Open your editor with Cline — rules are in .clinerules/"
    ;;
  aider)
    echo "Quick start: Run 'aider' in your project."
    echo "Conventions are loaded automatically from .aider.conf.yml"
    ;;
  gemini)
    echo "Quick start: Run 'gemini' in your project."
    echo "Skills are loaded from GEMINI.md at the project root."
    ;;
  antigravity)
    echo "Quick start: Open Antigravity — rules are in .antigravity/rules/"
    ;;
  agents-md)
    echo "Quick start: AGENTS.md is at your project root."
    echo "Compatible with any tool that reads AGENTS.md."
    ;;
  tabnine)
    echo "Quick start: Run 'tabnine' in your project."
    echo "Context is in TABNINE.md; per-skill detail in .sdlc/skills/"
    ;;
esac
