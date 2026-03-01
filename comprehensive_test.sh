#!/bin/bash
# Comprehensive test: all roles x all agents
SDLC_ROOT="/Users/kvel/Documents/manoj_ws/sdlc_central"
ALL_ROLES="product-owner architect developer qa devops-sre scrum-master designer"
ALL_AGENTS="claude-code cursor copilot windsurf cline aider gemini antigravity agents-md"

PASS=0
FAIL=0

echo "=== COMPREHENSIVE TEST: ALL ROLES x ALL AGENTS ==="
echo ""

for agent in $ALL_AGENTS; do
  for role in $ALL_ROLES; do
    TESTDIR="/tmp/sdlc-test-${agent}-${role}"
    rm -rf "$TESTDIR"
    mkdir -p "$TESTDIR"

    OUTPUT=$(cd "$TESTDIR" && bash "$SDLC_ROOT/setup/install-role.sh" "$role" --agent "$agent" 2>&1)
    SKILL_COUNT=$(echo "$OUTPUT" | grep -c "✓" || true)

    if [ "$SKILL_COUNT" -gt 0 ]; then
      echo "  ✓ ${agent} / ${role} — ${SKILL_COUNT} items"
      PASS=$((PASS + 1))
    else
      echo "  ✗ ${agent} / ${role} — FAILED"
      echo "    Output: $(echo "$OUTPUT" | tail -3)"
      FAIL=$((FAIL + 1))
    fi

    rm -rf "$TESTDIR"
  done
done

# Test tech-lead separately (delegates to install-all)
for agent in $ALL_AGENTS; do
  TESTDIR="/tmp/sdlc-test-${agent}-tech-lead"
  rm -rf "$TESTDIR"
  mkdir -p "$TESTDIR"

  OUTPUT=$(cd "$TESTDIR" && bash "$SDLC_ROOT/setup/install-role.sh" "tech-lead" --agent "$agent" 2>&1)
  SKILL_COUNT=$(echo "$OUTPUT" | grep -c "✓" || true)

  if [ "$SKILL_COUNT" -gt 0 ]; then
    echo "  ✓ ${agent} / tech-lead — ${SKILL_COUNT} items"
    PASS=$((PASS + 1))
  else
    echo "  ✗ ${agent} / tech-lead — FAILED"
    FAIL=$((FAIL + 1))
  fi

  rm -rf "$TESTDIR"
done

echo ""
echo "TOTAL: $PASS passed, $FAIL failed out of $((PASS + FAIL)) tests"
echo "(7 roles x 9 agents + 9 tech-lead = 72 tests)"
