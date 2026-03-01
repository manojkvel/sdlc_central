#!/bin/bash
# ------------------------------------------------------------------
# SDLC Central — Interactive Installer
# ------------------------------------------------------------------
# Run this from your project root:
#   bash /path/to/sdlc_central/setup/install.sh
# ------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SDLC_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "╔══════════════════════════════════════════════╗"
echo "║     SDLC Central — Interactive Installer      ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# --- Agent detection ---
DETECTED_AGENT=""
if [ -d ".claude" ]; then
  DETECTED_AGENT="claude-code"
elif [ -d ".cursor" ]; then
  DETECTED_AGENT="cursor"
elif [ -f ".github/copilot-instructions.md" ]; then
  DETECTED_AGENT="copilot"
elif [ -d ".windsurf" ]; then
  DETECTED_AGENT="windsurf"
elif [ -d ".clinerules" ] || [ -f ".clinerules" ]; then
  DETECTED_AGENT="cline"
elif [ -f ".aider.conf.yml" ]; then
  DETECTED_AGENT="aider"
elif [ -d ".antigravity" ]; then
  DETECTED_AGENT="antigravity"
elif [ -f "GEMINI.md" ]; then
  DETECTED_AGENT="gemini"
fi

echo "Select your coding agent:"
echo ""
echo "  1) Claude Code     (.claude/skills/)"
echo "  2) Cursor          (.cursor/rules/)"
echo "  3) GitHub Copilot  (.github/instructions/)"
echo "  4) Windsurf        (.windsurf/rules/)"
echo "  5) Cline           (.clinerules/)"
echo "  6) Aider           (CONVENTIONS.md)"
echo "  7) Gemini          (GEMINI.md)"
echo "  8) Antigravity     (.antigravity/rules/)"
echo "  9) AGENTS.md       (universal fallback)"
echo ""

if [ -n "$DETECTED_AGENT" ]; then
  echo "  Auto-detected: $DETECTED_AGENT"
  echo ""
fi

echo -n "Enter agent number [1]: "
read -r AGENT_NUM

case "${AGENT_NUM:-1}" in
  1) AGENT="claude-code" ;;
  2) AGENT="cursor" ;;
  3) AGENT="copilot" ;;
  4) AGENT="windsurf" ;;
  5) AGENT="cline" ;;
  6) AGENT="aider" ;;
  7) AGENT="gemini" ;;
  8) AGENT="antigravity" ;;
  9) AGENT="agents-md" ;;
  *)
    echo "Unknown selection: $AGENT_NUM — defaulting to claude-code"
    AGENT="claude-code"
    ;;
esac

echo ""
echo "Agent: $AGENT"
echo ""

# --- Role selection ---
echo "Select your role(s) to install the right skills and pipelines."
echo ""
echo "  1) Product Owner  (12 skills, 3 pipelines)"
echo "  2) Architect       (17 skills, 3 pipelines)"
echo "  3) Developer       (20 skills, 3 pipelines)"
echo "  4) QA              (10 skills, 3 pipelines)"
echo "  5) DevOps/SRE      (14 skills, 3 pipelines)"
echo "  6) Tech Lead       (50 skills, 3 pipelines)"
echo "  7) Scrum Master    ( 9 skills, 3 pipelines)"
echo "  8) Designer        ( 5 skills, 2 pipelines)"
echo "  9) All roles       (50 skills, all pipelines)"
echo ""
echo -n "Enter role number(s) separated by spaces [e.g. 1 3]: "
read -r SELECTION

if [ -z "$SELECTION" ]; then
  echo "No selection made. Exiting."
  exit 1
fi

ROLES=()
for num in $SELECTION; do
  case $num in
    1) ROLES+=("product-owner") ;;
    2) ROLES+=("architect") ;;
    3) ROLES+=("developer") ;;
    4) ROLES+=("qa") ;;
    5) ROLES+=("devops-sre") ;;
    6) ROLES+=("tech-lead") ;;
    7) ROLES+=("scrum-master") ;;
    8) ROLES+=("designer") ;;
    9)
      echo ""
      echo "Installing all roles..."
      bash "$SCRIPT_DIR/install-all.sh" --agent "$AGENT"
      exit 0
      ;;
    *)
      echo "Unknown selection: $num — skipping"
      ;;
  esac
done

if [ ${#ROLES[@]} -eq 0 ]; then
  echo "No valid roles selected. Exiting."
  exit 1
fi

echo ""
echo "Installing for role(s): ${ROLES[*]} (agent: $AGENT)"
echo ""

for role in "${ROLES[@]}"; do
  bash "$SCRIPT_DIR/install-role.sh" "$role" --agent "$AGENT"
done

echo ""
echo "════════════════════════════════════════════════"
echo "  Installation complete! (agent: $AGENT)"
echo "════════════════════════════════════════════════"
echo ""

case "$AGENT" in
  claude-code)
    echo "Run 'claude' in your project and try your new skills!"
    ;;
  cursor)
    echo "Open Cursor in your project — skills are loaded as .cursor/rules/"
    ;;
  copilot)
    echo "Open VS Code with Copilot — instructions are in .github/instructions/"
    ;;
  windsurf)
    echo "Open Windsurf in your project — rules are in .windsurf/rules/"
    ;;
  cline)
    echo "Open your editor with Cline — rules are in .clinerules/"
    ;;
  aider)
    echo "Run 'aider' in your project — conventions are loaded from .aider.conf.yml"
    ;;
  gemini)
    echo "Run 'gemini' in your project — skills are in GEMINI.md"
    ;;
  antigravity)
    echo "Open Antigravity — rules are in .antigravity/rules/"
    ;;
  agents-md)
    echo "AGENTS.md is at your project root — compatible with any AGENTS.md-aware tool."
    ;;
esac
