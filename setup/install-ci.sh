#!/bin/bash
# Copy the AIDLC CI workflow into the project (.github/workflows/aidlc-checks.yml).
# Usage: bash /path/to/sdlc_central/setup/install-ci.sh [--agent-dir .claude]
set -e
SDLC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AD=".claude"; [ "$1" = "--agent-dir" ] && AD="$2"
mkdir -p .github/workflows
if [ -f .github/workflows/aidlc-checks.yml ]; then echo "  ○ .github/workflows/aidlc-checks.yml exists — preserved"; exit 0; fi
sed "s|AGENT_DIR: .claude|AGENT_DIR: $AD|" "$SDLC_ROOT/adapters/_shared/ci/aidlc-checks.yml" > .github/workflows/aidlc-checks.yml
echo "  ✓ .github/workflows/aidlc-checks.yml (agent dir $AD)"
