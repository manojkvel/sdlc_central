#!/bin/bash
# ------------------------------------------------------------------
# SDLC Central — Non-Interactive Role Installer
# ------------------------------------------------------------------
# Usage:
#   bash /path/to/sdlc_central/setup/install-role.sh <role> [--agent <agent>]
#
# Roles: product-owner, architect, developer, qa, devops-sre,
#        tech-lead, scrum-master, designer
#
# Agents: claude-code (default), cursor, copilot, windsurf, cline, aider, gemini, antigravity, agents-md
# ------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDLC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$(pwd)"
VERSION="1.0.0"

# --- Parse arguments ---
ROLE=""
AGENT="claude-code"

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
    *)
      if [ -z "$ROLE" ]; then
        ROLE="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$ROLE" ]; then
  echo "Usage: install-role.sh <role> [--agent <agent>]"
  echo ""
  echo "Roles: product-owner, architect, developer, qa, devops-sre, tech-lead, scrum-master, designer"
  echo "Agents: claude-code (default), cursor, copilot, windsurf, cline, aider, gemini, antigravity, agents-md"
  exit 1
fi

# Validate agent
VALID_AGENTS="claude-code cursor copilot windsurf cline aider gemini antigravity agents-md"
if ! echo "$VALID_AGENTS" | grep -qw "$AGENT"; then
  echo "Unknown agent: $AGENT"
  echo "Valid agents: $VALID_AGENTS"
  exit 1
fi

# --- Role → Skill Mappings ---
case "$ROLE" in
  product-owner)
    SKILLS=(feature-balance-sheet spec-gen quality-gate gate-briefing scope-tracker board-sync report-trends risk-tracker release-readiness-checker release-notes decision-log drift-detector changelog-plain progress-summary demo-prep user-story-refiner bug-report codebase-qa)
    PIPELINES=(feature-intake sprint-health release-signoff stakeholder-update idea-to-spec sprint-demo)
    ;;
  architect)
    SKILLS=(design-review plan-gen quality-gate decision-log tech-debt-audit code-ownership-mapper api-contract-analyzer report-trends migration-tracker impact-analysis plan-merge spec-gen spec-review spec-evolve feature-balance-sheet gate-briefing reverse-engineer)
    PIPELINES=(design-to-plan system-health migration-planning)
    ;;
  developer)
    SKILLS=(task-gen wave-scheduler task-implementer spec-review review-fix pr-orchestrator review security-audit test-gen dependency-update tech-debt-audit regression-check spec-fix doc-gen perf-review plan-gen spec-gen impact-analysis onboarding-guide design-review)
    PIPELINES=(feature-build pr-workflow maintenance)
    ;;
  qa)
    SKILLS=(spec-review test-gen regression-check perf-review report-trends release-readiness-checker quality-gate security-audit api-contract-analyzer drift-detector bug-report codebase-qa)
    PIPELINES=(test-strategy regression-suite release-validation bug-to-fix)
    ;;
  devops-sre)
    SKILLS=(release-readiness-checker incident-detector slo-sla-tracker incident-triager rollback-assessor approval-workflow-auditor cross-repo-standards-enforcer pipeline-monitor dependency-update security-audit incident-postmortem-synthesizer migration-tracker report-trends risk-tracker)
    PIPELINES=(deploy-verify incident-response platform-health)
    ;;
  tech-lead)
    # Tech lead gets everything
    bash "$SCRIPT_DIR/install-all.sh" --agent "$AGENT"
    exit 0
    ;;
  scrum-master)
    SKILLS=(board-sync scope-tracker risk-tracker feedback-loop report-trends pipeline-monitor auto-triage wave-scheduler gate-briefing changelog-plain progress-summary demo-prep bug-report codebase-qa)
    PIPELINES=(sprint-tracking retrospective-data impediment-tracker)
    ;;
  designer)
    SKILLS=(spec-gen spec-review design-review api-contract-analyzer doc-gen design-to-code design-token-sync component-audit visual-review bug-report codebase-qa user-story-refiner changelog-plain)
    PIPELINES=(spec-collaboration design-validation design-implementation design-system-sync design-handoff)
    ;;
  *)
    echo "Unknown role: $ROLE"
    echo "Valid roles: product-owner, architect, developer, qa, devops-sre, tech-lead, scrum-master, designer"
    exit 1
    ;;
esac

echo "╔══════════════════════════════════════════════╗"
echo "║     SDLC Central — $ROLE ($AGENT)"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "Installing ${#SKILLS[@]} skills + ${#PIPELINES[@]} pipelines into: $PROJECT_DIR"
echo "Agent: $AGENT"
echo ""

# --- Install skills via adapter ---
ADAPTER="$SDLC_ROOT/adapters/$AGENT/adapter.sh"

if [ -f "$ADAPTER" ]; then
  echo "Skills (via $AGENT adapter):"
  bash "$ADAPTER" "$SDLC_ROOT" "$PROJECT_DIR" "${SKILLS[@]}"
  INSTALLED=${#SKILLS[@]}
else
  # Fallback: direct copy for claude-code (backward compat)
  echo "Skills:"
  INSTALLED=0
  for skill in "${SKILLS[@]}"; do
    mkdir -p "$PROJECT_DIR/.claude/skills/$skill"
    if [ -f "$SDLC_ROOT/skills/$skill/SKILL.md" ]; then
      cp "$SDLC_ROOT/skills/$skill/SKILL.md" "$PROJECT_DIR/.claude/skills/$skill/SKILL.md"
      echo "  ✓ $skill"
      INSTALLED=$((INSTALLED + 1))
    else
      echo "  ✗ $skill (not found)"
    fi
  done
fi

# --- Install role pipelines ---
# Pipelines are agent-agnostic YAML — install for all agents
echo ""
echo "Pipelines:"

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

mkdir -p "$PIPELINE_DIR/$ROLE"
for pipeline in "${PIPELINES[@]}"; do
  if [ -f "$SDLC_ROOT/pipelines/$ROLE/$pipeline.pipeline.yaml" ]; then
    cp "$SDLC_ROOT/pipelines/$ROLE/$pipeline.pipeline.yaml" "$PIPELINE_DIR/$ROLE/"
    echo "  ✓ $ROLE/$pipeline"
  else
    echo "  ○ $ROLE/$pipeline (pipeline definition not found)"
  fi
done

# --- Install config (preserve existing) ---
echo ""
echo "Config:"

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
  echo "  ✓ gate-config.json"
else
  echo "  ○ gate-config.json (preserved)"
fi
if [ ! -f "$CONFIG_DIR/balance-sheet-config.json" ]; then
  cp "$SDLC_ROOT/config/balance-sheet-config.json" "$CONFIG_DIR/balance-sheet-config.json"
  echo "  ✓ balance-sheet-config.json"
else
  echo "  ○ balance-sheet-config.json (preserved)"
fi

# --- Write/update tracking file ---
TRACKING_DIR="$PROJECT_DIR/.sdlc"
mkdir -p "$TRACKING_DIR"
TRACKING_FILE="$TRACKING_DIR/sdlc-central.json"

# Also write to .claude/ for backward compat when using claude-code
if [ "$AGENT" = "claude-code" ]; then
  TRACKING_FILE="$PROJECT_DIR/.claude/sdlc-central.json"
fi

ROLES_JSON="[\"$ROLE\"]"
if [ -f "$TRACKING_FILE" ]; then
  EXISTING_ROLES=$(cat "$TRACKING_FILE" | grep '"roles"' | sed 's/.*\[/[/' | sed 's/\].*/]/')
  if echo "$EXISTING_ROLES" | grep -q "$ROLE"; then
    ROLES_JSON="$EXISTING_ROLES"
  else
    ROLES_JSON=$(echo "$EXISTING_ROLES" | sed "s/\]/,\"$ROLE\"]/")
  fi
fi

cat > "$TRACKING_FILE" << EOF
{
  "version": "$VERSION",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source": "$SDLC_ROOT",
  "agent": "$AGENT",
  "roles": $ROLES_JSON,
  "skill_count": $INSTALLED,
  "pipelines_installed": true
}
EOF

# --- Agent-specific project file ---
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
      ROLE_TMPL="$TMPL_DIR/CLAUDE.md.$ROLE"
      [ ! -f "$ROLE_TMPL" ] && ROLE_TMPL="$SDLC_ROOT/templates/CLAUDE.md.$ROLE"
      if [ -f "$ROLE_TMPL" ]; then
        echo "" >> "$PROJECT_DIR/CLAUDE.md"
        cat "$ROLE_TMPL" >> "$PROJECT_DIR/CLAUDE.md"
      fi
      echo "Created CLAUDE.md with $ROLE skill reference."
    else
      echo "CLAUDE.md exists — preserved."
    fi
    ;;
  cursor)
    echo "Cursor rules installed to .cursor/rules/"
    ;;
  copilot)
    echo "Copilot instructions installed to .github/instructions/"
    ;;
  windsurf)
    echo "Windsurf rules installed to .windsurf/rules/"
    ;;
  cline)
    echo "Cline rules installed to .clinerules/"
    ;;
  aider)
    echo "Aider conventions installed to CONVENTIONS.md + .sdlc/skills/"
    ;;
  gemini)
    echo "GEMINI.md installed at project root."
    ;;
  antigravity)
    echo "Antigravity rules installed to .antigravity/rules/"
    ;;
  agents-md)
    echo "AGENTS.md installed at project root."
    ;;
esac

echo ""
echo "  Done! $INSTALLED skills + ${#PIPELINES[@]} pipelines installed for $ROLE ($AGENT)."
