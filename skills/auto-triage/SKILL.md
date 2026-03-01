---
name: auto-triage
description: Automated failure recovery for the SDLC pipeline — classifies failures from any pipeline stage, attempts automated recovery (retry, /review-fix, /spec-fix, /spec-evolve), and only escalates to a HITL gate when the failure genuinely requires a human decision. Sits between /quality-gate failure and human escalation.
argument-hint: "path/to/failed-artifact-or-report [--max-retries 3] [--escalate-after 2]"
allowed-tools: Read, Write, Grep, Glob, Bash(git log, git diff, git show, git stash, git checkout, ls, find, cat, wc, date, jq)
---

# Auto-Triage — Automated Pipeline Failure Recovery

When a pipeline step fails, the naive response is to stop and wait for a human. But most failures are recoverable by the pipeline itself: tests failing means generate better tests or fix the code; review findings mean run `/review-fix`; spec compliance gaps mean run `/spec-fix`. Only a subset of failures genuinely need human judgment.

`/auto-triage` classifies every failure, attempts automated recovery, and escalates only when it must. This keeps the pipeline moving and reserves human attention for decisions only humans can make.

## Failure Classification

| Class | Description | Recovery Path | Escalation |
|-------|------------|--------------|------------|
| TEST_FAILURE | Tests fail after implementation | Re-analyze failure, fix code or test → retry | After 2 failed retries |
| REVIEW_FINDING | /review finds CRITICAL/HIGH issues | /review-fix → re-review | After 2 fix cycles with no improvement |
| SECURITY_FINDING | /security-audit finds vulnerabilities | /review-fix (security mode) → re-audit | CRITICAL findings that need architecture change |
| SPEC_COMPLIANCE | /spec-review finds gaps | /spec-fix → re-review | Gaps that require spec amendment |
| SPEC_AMBIGUITY | /task-implementer hits unclear requirement | Attempt resolution from context → /spec-evolve resolve | If answer isn't in existing artifacts |
| DEPENDENCY_FAILURE | External dependency unavailable | Retry with backoff → check alternatives | After timeout threshold |
| GATE_FAILURE | /quality-gate fails | Route based on failure type → re-evaluate | Non-recoverable criteria |
| BUILD_FAILURE | Code doesn't compile/build | Analyze error, fix → retry | After 2 retries |
| CONFLICT | Two tasks modify same file | Merge resolution → retry | Semantic conflicts |
| SCOPE_GAP | Implementation reveals missing scope | /spec-evolve child or revise | Always (scope decisions need human) |

## CRITICAL RULES

1. **Maximum retry depth.** No recovery path retries more than `--max-retries` times (default: 3). Infinite loops are the worst failure mode.
2. **Escalation is not failure.** Routing to a HITL gate is a normal outcome, not an error. The triage report should help the human resolve quickly.
3. **Track recovery attempts.** Every attempt is logged in `triage-log.json` for `/feedback-loop` analysis.
4. **Don't mask problems.** If a test fails, the goal is to fix the root cause — not to weaken the test. If a security finding is valid, the goal is to fix the code — not to suppress the finding.
5. **Scope decisions always escalate.** When the failure reveals that the spec is missing something, only a human can decide whether to expand scope.

---

## Phase 0 — Classify the Failure

### 0.1 Identify Failure Source

Read the failed artifact or report:
```
Parse the error output, report findings, or gate failure reasons.
Identify: which skill failed, what the error is, which artifact was being processed.
```

### 0.2 Classify

Apply the classification table above. Key signals:

| Signal | Classification |
|--------|---------------|
| "AssertionError", "FAIL", test output | TEST_FAILURE |
| "CRITICAL:", "HIGH:" in review report | REVIEW_FINDING |
| "CVE-", "vulnerability" in security report | SECURITY_FINDING |
| "NOT_COMPLIANT", "gap" in spec-review | SPEC_COMPLIANCE |
| "ambiguous", "unclear", "which approach" | SPEC_AMBIGUITY |
| "connection refused", "timeout", "not found" | DEPENDENCY_FAILURE |
| "FAIL" in gate report | GATE_FAILURE |
| "SyntaxError", "TypeError", "compile error" | BUILD_FAILURE |
| "conflict", "merge conflict" | CONFLICT |
| "not in spec", "out of scope", "need new AC" | SCOPE_GAP |

### 0.3 Check Recovery History

Read `triage-log.json` for this artifact:
- Has this failure been seen before?
- How many recovery attempts have been made?
- Is this the same failure recurring (indicating the recovery strategy isn't working)?

---

## Phase 1 — Attempt Recovery

### 1.1 TEST_FAILURE Recovery

```
1. Parse test output to identify failing tests
2. Analyze: is the test wrong or is the code wrong?
   - If test expectations don't match spec ACs → test is wrong → regenerate test
   - If code doesn't produce expected output → code is wrong → fix implementation
3. Apply fix
4. Re-run tests
5. If pass → recovery successful
6. If fail with SAME error → increment retry count → retry or escalate
7. If fail with DIFFERENT error → reclassify → new recovery attempt
```

### 1.2 REVIEW_FINDING Recovery

```
1. Invoke /review-fix on the review report
2. /review-fix applies fixes for CRITICAL and HIGH findings
3. Re-run /review to verify fixes
4. If no CRITICAL/HIGH remain → recovery successful
5. If findings persist or new ones appear → check if improvement was made
   - Improvement (fewer findings) → retry
   - No improvement → escalate with context
```

### 1.3 SECURITY_FINDING Recovery

```
1. Invoke /review-fix in security mode
2. For each finding:
   - Injection/XSS → add input validation/sanitization
   - Auth bypass → fix auth check
   - Hardcoded secret → extract to env var
   - Dependency CVE → /dependency-update --fix-security
3. Re-run /security-audit
4. If no CRITICAL remain → recovery successful
5. If CRITICAL persist → escalate (may need architecture change)
```

### 1.4 SPEC_COMPLIANCE Recovery

```
1. Invoke /spec-fix on the spec-review report
2. /spec-fix implements missing ACs, resolves scope creep, enforces BRs
3. Re-run /spec-review
4. If COMPLIANT or MOSTLY_COMPLIANT (≥85%) → recovery successful
5. If gaps remain:
   - Missing AC implementation → retry /spec-fix with more context
   - Spec itself is ambiguous → route to /spec-evolve resolve
   - Spec is missing requirements → route to /spec-evolve revise → HITL gate
```

### 1.5 SPEC_AMBIGUITY Recovery

```
1. Read the ambiguity description from the task-implementer report
2. Search existing artifacts for the answer:
   - Check spec.md for relevant ACs, BRs, constraints
   - Check plan.md for architecture decisions
   - Check gate feedback for prior reviewer comments
3. If answer found in existing artifacts → /spec-evolve resolve (automated)
4. If answer NOT found → escalate to HITL gate with context
   - Provide the question
   - Provide relevant spec context
   - Suggest 2-3 possible answers with trade-offs
```

### 1.6 GATE_FAILURE Recovery

```
1. Read the gate report to identify failed criteria
2. For each failed criterion, determine if it's auto-recoverable:
   - Test coverage too low → run /test-gen for uncovered paths → re-gate
   - Missing DoD → add DoD to tasks → re-gate
   - Stale artifacts → re-run upstream stage → re-gate
   - Open questions → route to /spec-evolve resolve or HITL gate
3. Execute auto-recoverable fixes
4. Re-evaluate the gate
5. If gate passes → recovery successful
6. If gate still fails → escalate remaining failures
```

---

## Phase 2 — Log and Report

### 2.1 Update Triage Log

Append to `triage-log.json`:

```json
{
  "entries": [
    {
      "id": "triage-047-005",
      "date": "2026-02-16T14:30:00Z",
      "pipeline": "pipe-047-sso-login-20260216",
      "stage": "task-implementer-wave-2",
      "task": "TASK-005",
      "classification": "TEST_FAILURE",
      "description": "3 of 8 tests failing in auth service — token refresh test expects fixed expiry, code uses sliding window",
      "recovery_attempts": [
        {
          "attempt": 1,
          "action": "Fix test expectations to match sliding window behavior",
          "result": "2 of 3 failures resolved",
          "remaining": "1 test still failing — edge case: concurrent refresh"
        },
        {
          "attempt": 2,
          "action": "Fix concurrent refresh handling in code",
          "result": "All tests passing",
          "remaining": null
        }
      ],
      "outcome": "RECOVERED",
      "total_attempts": 2,
      "escalated": false,
      "duration_seconds": 120
    }
  ]
}
```

### 2.2 Console Output (Recovery Successful)

```
Auto-Triage — TASK-005
━━━━━━━━━━━━━━━━━━━━━━
Classification: TEST_FAILURE
Attempts:       2

Attempt 1: Fixed test expectations (sliding window)
  Result:  2/3 resolved, 1 remaining
Attempt 2: Fixed concurrent refresh handling
  Result:  All tests passing ✓

Outcome: RECOVERED — pipeline continues
Duration: 2m 0s
```

### 2.3 Console Output (Escalation)

```
Auto-Triage — TASK-008
━━━━━━━━━━━━━━━━━━━━━━
Classification: SPEC_AMBIGUITY
Attempts:       1

Attempt 1: Searched spec, plan, gate feedback for answer
  Result:  No clear answer found

ESCALATING to HITL gate:
  Question: "Should SSO support both IdP-initiated and SP-initiated flows?"
  Context:  Spec AC-2 says "support enterprise SSO" but doesn't specify initiation mode.
  Options:
    A) SP-initiated only (simpler, covers 80% of enterprise use cases)
    B) Both (full enterprise compatibility, +2 tasks estimated)
    C) Defer to child spec (implement SP-initiated now, add IdP-initiated later)

Waiting for human decision...
```

---

## Integration with Pipeline

### With /pipeline-orchestrator
The orchestrator invokes `/auto-triage` whenever a stage fails or a `/quality-gate` returns FAIL. Based on the triage outcome (RECOVERED or ESCALATED), the orchestrator either continues the pipeline or pauses at a HITL gate.

### With /feedback-loop
`/feedback-loop` analyzes `triage-log.json` to find patterns: which failure types are most common, which recovery strategies succeed most often, which failures always end up escalating (suggesting the auto-recovery strategy needs improvement).

### With /spec-evolve
`/auto-triage` routes to `/spec-evolve` when the failure is rooted in the spec: ambiguities go to `resolve` mode, missing scope goes to `child` mode, and spec inconsistencies go to `revise` mode.

---

## Modes

```
/auto-triage reports/task-implementer-sso-login-2026-02-16.md
/auto-triage specs/047-sso-login/gate-impl-to-release-2026-02-16.md
/auto-triage --max-retries 2 --escalate-after 1 specs/047-sso-login/
```

---

## Output

1. **Triage log:** `triage-log.json` — append-only recovery attempt history
2. **Recovery artifacts:** Fixed code, regenerated tests, applied fixes (produced by downstream skills)
3. **Escalation brief:** When escalating to HITL, produces a structured question with context and options
4. **Console summary:** Classification, recovery attempts, outcome (RECOVERED or ESCALATED)
