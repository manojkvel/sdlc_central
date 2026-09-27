#!/bin/bash
# Install matrix.
#   bash comprehensive_test.sh                 supported surface: 3 roles x 2 agents, tech-lead, and refusal of experimental agents
#   bash comprehensive_test.sh --experimental  the frozen full matrix: 8 roles x 10 agents + tech-lead, installed with --experimental
SDLC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0; FAIL=0
ok()  { echo "  ✓ $1"; PASS=$((PASS + 1)); }
bad() { echo "  ✗ $1"; [ -n "$2" ] && echo "    $2"; FAIL=$((FAIL + 1)); }

install_case() { # install_case <role> <agent> [flags...]
  local role="$1" agent="$2"; shift 2
  local dir; dir="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-matrix.XXXXXX")"
  local out rc
  out="$(cd "$dir" && bash "$SDLC_ROOT/setup/install-role.sh" "$role" --agent "$agent" "$@" 2>&1)"; rc=$?
  local items; items="$(printf '%s\n' "$out" | grep -c "✓")"
  if [ $rc -eq 0 ] && [ "$items" -gt 0 ]; then ok "$agent / $role — $items items"; else bad "$agent / $role — exit $rc" "$(printf '%s\n' "$out" | tail -3)"; fi
  rm -rf "$dir"
}

if [ "$1" = "--experimental" ]; then
  echo "=== INSTALL MATRIX (experimental, frozen surface) ==="
  for agent in claude-code cursor copilot windsurf cline aider gemini antigravity agents-md tabnine; do
    for role in product-owner architect developer qa devops-sre scrum-master designer release-manager tech-lead; do
      install_case "$role" "$agent" --experimental
    done
  done
else
  echo "=== INSTALL MATRIX (supported surface) ==="
  for agent in claude-code agents-md; do
    for role in product-owner architect developer tech-lead; do install_case "$role" "$agent"; done
  done
  # Experimental agents are refused without --experimental (exit 3), with a way forward.
  dir="$(mktemp -d "${TMPDIR:-/tmp}/sdlc-matrix.XXXXXX")"
  out="$(cd "$dir" && bash "$SDLC_ROOT/setup/install-role.sh" developer --agent cursor 2>&1)"; rc=$?
  if [ $rc -eq 3 ] && printf '%s' "$out" | grep -q -- "--experimental"; then ok "cursor refused without --experimental"; else bad "cursor should be refused (exit $rc)"; fi
  rm -rf "$dir"
fi

echo ""
echo "TOTAL: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests"
[ $FAIL -eq 0 ]
