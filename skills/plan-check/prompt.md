# Plan Check

Audit an implementation plan **before a line of code is written**, and write `PLAN_CHECK.md`. This is the pre-execution gate of the AIDLC lifecycle: on tier 2 and 3 work, the `aidlc-pre-write-guard` hook refuses every source write until `PLAN_CHECK.md` ends with `## PLAN CHECK PASSED`. It catches missing logic, unmapped criteria and unbounded scope while they are cheap to fix.

You act as the **aidlc-plan-checker**: independent of the plan's author. You report findings; you do not fix the plan.

## AIDLC contract

- Track root: read `track_root` from the agent's `sdlc-central.json`; default `.track/`.
- Before writing: read `<track root>/state.md`. If `BLOCKED_GATE` is not `none`, stop and end with `## AIDLC GATE BLOCKED`.
- After writing an artifact: append one lineage line to `<track root>/lineage.md`:
  `<ISO time> | - | <family.event>: <detail> | <artifact path> | sha256:<hash> | model=<model id> | sdlc=<version>`
- End with exactly one completion marker from this skill's `markers`.
- Never cite `SUMMARY.md`, a summary, or a file's existence as proof of behaviour. Cite command output or an evidence entry.
- Never write `human-decisions.md`. Decisions are recorded only by `aidlc-human-approval-guard`.
- Never read `evidence/index.json`, `lineage.md` or `guardrail-log.md` whole; they grow with every run. Use `aidlc-evidence.sh summary` or `list`, the summary block at the top of `VERIFICATION.md` or `SCORECARD.md`, and `grep '<phase>' lineage.md | tail -20`.

## CRITICAL RULES

1. **Findings are binary.** Every check is PASS or FAIL. One FAIL means the plan check fails. Advisory notes go in their own section and do not affect the result.
2. **Run the deterministic check first.** The id mapping is computed by a script, not by reading. Report its output verbatim.
3. **Do not edit PLAN.md, SPEC.md or TASKS.md.** The author fixes the plan; you re-run.
4. **Name the gap precisely.** A finding says which id, which file, which line, and what would make it pass.

---

## Phase 1 — Locate the phase

Read `<track root>/state.md` and take `CURRENT_PHASE` from the `## AIDLC_RESUME` block, unless a phase directory was passed as the argument. The phase directory is `<track root>/phases/<CURRENT_PHASE>/`.

Required inputs: `SPEC.md` and `PLAN.md`. Optional: `TECHNICAL_DESIGN.md`, `TASKS.md`, `unit.yaml`, `<track root>/requirements.md`, `<track root>/decisions.md`, `<track root>/risks.md`.

If `SPEC.md` or `PLAN.md` is missing, write `PLAN_CHECK.md` with a single FAIL finding naming the missing file and end with `## AIDLC GATE BLOCKED`.

## Phase 2 — Deterministic id mapping

Run the traceability script installed with the hooks (the agent directory is `.claude/`, `.cursor/`, `.github/` or `.sdlc/`):

```bash
bash <agent-dir>/hooks/aidlc-traceability-check/aidlc-traceability-check.sh --phase <NN-slug>
```

Exit 0 prints `T00 traced`. Exit 2 lists every gap with its code:
- `T01` orphan requirement, `T02` AC or SC missing from PLAN.md, `T03` dangling D/DEC/RISK id, `T04` task that names no AC or SC.

Copy each line into the findings table. Any T-code is a FAIL.

## Phase 3 — Judgement checks

| # | Check | FAIL when |
|---|---|---|
| P1 | **Coverage depth** | An AC is mentioned in PLAN.md but no phase or step would actually satisfy it (for example it appears only in a summary list) |
| P2 | **Edge cases** | An edge case listed in SPEC.md has no test or step in the plan |
| P3 | **Scope bound** | The plan changes files or behaviour no AC asks for (scope creep), or touches a path outside `unit.yaml` `repos` |
| P4 | **Destructive commands declared** | The plan implies a migration, deploy, data deletion, infra apply or force push, and does not list the exact command under `## Permitted destructive commands` |
| P5 | **Rollback** | Tier 2 or 3, and the plan has no `## Rollback` section with concrete steps |
| P6 | **Test first** | Implementation steps precede the tests that verify them |
| P7 | **Design alignment** | `TECHNICAL_DESIGN.md` exists and the plan contradicts a decision in it or in `decisions.md` |
| P8 | **Risk handling** | A risk in `risks.md` or in the plan's own risk section has no mitigation step and no owner |
| P9 | **Contracts (tier 3)** | The unit consumes a contract (`unit.yaml` `consumes`) and the plan does not name the contract version it builds against |

Read the code the plan touches when a check needs it. Keep each finding to one line.

## Phase 4 — Write PLAN_CHECK.md

Write `<phase dir>/PLAN_CHECK.md`:

```markdown
<!-- generated-by: plan-check -->
# Plan check — <NN-slug>

- **Checked:** <ISO time>
- **Plan:** `PLAN.md` sha256:<hash>
- **Spec:** `SPEC.md` sha256:<hash>
- **Traceability script:** <T00 traced | the T-codes>

## Findings

| # | Check | Result | Detail | To pass |
|---|---|---|---|---|
| T02 | AC-3 in PLAN.md | FAIL | AC-3 (refund window) appears in no phase | add a step and a test for AC-3 |
| P5 | Rollback | PASS | — | — |

## Advisory
- <non-blocking observations>

## PLAN CHECK PASSED
```

Hash the files with `shasum -a 256 <file>`. The last line is exactly one marker:
- `## PLAN CHECK PASSED` when every row is PASS
- `## AIDLC GATE BLOCKED` otherwise, preceded by a one-line summary: `<n> finding(s) block execution; the plan author fixes them and re-runs /plan-check.`

Append the lineage line: `evidence.recorded: plan-check <PASSED|BLOCKED>` for `PLAN_CHECK.md` with its hash.

## Phase 5 — Report

Print the findings table and the marker. When the check passed, tell the user the plan is ready for its approval gate (`APPROVE PLAN`), and that source writes unlock only after that decision is recorded.
