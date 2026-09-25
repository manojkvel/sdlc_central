#!/bin/bash
# Copy the AIDLC CI workflow into the project (.github/workflows/aidlc-checks.yml).
# Usage: bash /path/to/sdlc_central/setup/install-ci.sh [--agent-dir .claude] [--decisions]
#   --decisions  also install the decision bot workflow (authenticated gate decisions)
set -e
SDLC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AD=".claude"; DECISIONS=0
while [ $# -gt 0 ]; do case "$1" in --agent-dir) AD="$2"; shift 2 ;; --decisions) DECISIONS=1; shift ;; *) shift ;; esac; done
mkdir -p .github/workflows
if [ $DECISIONS -eq 1 ]; then
  if [ -f .github/workflows/aidlc-decision.yml ]; then echo "  ○ .github/workflows/aidlc-decision.yml exists — preserved"
  else sed "s|AGENT_DIR: .claude|AGENT_DIR: $AD|" "$SDLC_ROOT/adapters/_shared/ci/aidlc-decision.yml" > .github/workflows/aidlc-decision.yml
    echo "  ✓ .github/workflows/aidlc-decision.yml (decision bot). After it works, set authenticated_identity_required: true in $AD/config/gate-config.json"; fi
fi
if [ -f .github/workflows/aidlc-checks.yml ]; then echo "  ○ .github/workflows/aidlc-checks.yml exists — preserved"; exit 0; fi
sed "s|AGENT_DIR: .claude|AGENT_DIR: $AD|" "$SDLC_ROOT/adapters/_shared/ci/aidlc-checks.yml" > .github/workflows/aidlc-checks.yml
echo "  ✓ .github/workflows/aidlc-checks.yml (agent dir $AD)"
