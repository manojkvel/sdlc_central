---
name: run-pipeline
description: "Execute a pipeline YAML — resolve steps, invoke skills in order, enforce gates, persist state for resume."
argument-hint: "<role>/<pipeline-name> [args] [--dry-run] [--resume] [--gates minimal|standard|strict]"
allowed-tools: Read, Write, Grep, Glob, Bash(git log, git diff, ls, find, date, jq, shasum, bash)
---

# Pipeline Runner

Execute role-specific pipeline workflows that chain skills into automated sequences. Reads a YAML definition, runs skills in dependency order, enforces quality gates, and saves state for resume.

## CRITICAL RULES

1. **Read the pipeline YAML first.** Never guess — load and parse the definition.
2. **Respect gate conditions.** `on_fail: stop` means stop. `on_fail: hitl` means pause for human input.
3. **Save state after every step.** Write `pipeline-state.json` so the pipeline can resume.
4. **Never skip HITL gates.** Human approval gates are mandatory pause points.
5. **Interpolate arguments correctly.** `$INPUT` = user's original input. `$step-id.output` = output from a completed step.
6. **Never record a decision yourself.** Gate decisions are written only by `aidlc-human-approval-guard`. You publish a checkpoint and stop; the guard records the human's reply.
7. **The track root is the source of truth.** When `<track root>/state.md` exists, resume from its `## AIDLC_RESUME` block, not from memory or from the run file.

## Phase 0 — AIDLC Track (when the project has a track root)

Read `track_root` from the agent's `sdlc-central.json` (default `.track`). If `<track root>/state.md` does not exist, skip Phase 0 and every AIDLC step below: the pipeline runs exactly as before.

When it exists:

1. **Resume block.** Read `## AIDLC_RESUME` in `state.md`. If `BLOCKED_GATE` is not `none`, do not run any step: restate the open checkpoint (below) and stop.
2. **Phase directory.** A new unit of work gets the next `phases/NN-<slug>/` directory and a `unit.yaml` (`id`, `name`, `profile`, `tier`; schema `config/schemas/unit.schema.json`). Artifacts go there under upper-case names: `SPEC.md`, `TECHNICAL_DESIGN.md`, `PLAN.md`, `PLAN_CHECK.md`, `TASKS.md`, `SUMMARY.md`, `VERIFICATION.md`, `REVIEW.md`, `SCORECARD.md`.
3. **Tier.** Use `unit.yaml` `tier`. Otherwise infer it: a work-type `profile` (see `config/profiles.yaml`) sets the floor; then tier 3 if any contract is consumed or produced, tier 1 if the spec has fewer than 3 acceptance criteria and touches one repository, else tier 2. Write the tier back to `unit.yaml`.
4. **Gate profile.** Resolve it through `tier_map` in `gate-config.json` (1 → minimal, 2 → standard, 3 → strict). `--gates` may raise the profile, never lower it.
5. **Risk level of each HITL gate.** `risk_levels[<gate>][<profile>]` in `gate-config.json`. An open security finding in `risks.md` or `REVIEW.md` makes every gate `security-sensitive`.

### Checkpoint block (replaces a free-form approval question)

At a HITL gate, update the resume block, then print the checkpoint and **end your turn**:

- Set `CURRENT_STAGE`, `BLOCKED_GATE: <gate id>`, `GATE_RISK: <risk>`, `GATE_REMINDED: no`, `NEXT_ACTION: Reply with one of the decision strings below`, `NEXT_ACTION_OWNER: human:<role>`, `NEXT_ACTION_INPUTS: <comma-separated artifact paths under review>`.
- Append a lineage line `decision.checkpoint_published: <gate>` with the first artifact and its hash.
- Print:

```
## AIDLC CHECKPOINT REQUIRED
Gate: <gate id>   Risk: <risk>   Phase: <NN-slug>
Review: <artifact paths with sha256>
Summary: <gate-briefing summary, 5 lines at most>
Reply with exactly one of:
  APPROVE <GATE>[: <risk acknowledgement | release scope, required at high / release risk>]
  APPROVE WITH RISK: <risk and excluded scope>
  REQUEST CHANGES: <reason>
  REQUEST VERIFICATION: <missing evidence>
  DEFER            (DEFER RELEASE | REJECT RELEASE at a release gate)
```

On an enforcing agent (Claude Code) the human's reply is intercepted by the prompt hook, which records `HD-NNN` and prints a `DECISION RECEIPT`. On an advisory agent, the first thing you do with the reply is pass it to the guard, verbatim:

```bash
printf '%s' '{"prompt": <the reply as a JSON string>}' | bash <agent-dir>/hooks/aidlc-human-approval-guard/aidlc-human-approval-guard.sh
```

Exit 2 means the reply was rejected: show the guard's message and stop. Exit 0 with a receipt means the decision is recorded. Exit 0 without a receipt means the reply was discussion, not a decision: answer it and restate the checkpoint.

After a receipt, continue only when `BLOCKED_GATE` is back to `none`. `REQUEST CHANGES` and `REQUEST VERIFICATION` route to the step that produced the artifact, then republish the checkpoint.

### After every step

- Rewrite the whole `## AIDLC_RESUME` block: `CURRENT_PHASE`, `CURRENT_STAGE`, `BLOCKED_GATE`, `GATE_RISK`, `NEXT_ACTION`, `NEXT_ACTION_OWNER`, `NEXT_ACTION_INPUTS`, `DONE` (steps completed), `EVIDENCE` (evidence index path or `none`), `OPEN_RISKS` (RISK ids or `none`). Keep the `## Phases` table current.
- Append lineage lines: `stage.entered: <stage>` on every stage change, and one `<family>.<event>` line per artifact written, with its sha256. Families: stage, decision, evidence, contract, handoff, knowledge, guardrail, cost.
- Keep context small: never load `evidence/index.json`, `lineage.md` or `guardrail-log.md` whole. Use `aidlc-evidence.sh summary`, the summary blocks of `VERIFICATION.md` and `SCORECARD.md`, and `grep '<phase>' lineage.md | tail -20`. Resume from the `## AIDLC_RESUME` block alone; open other artifacts only when the next step needs them.
- At each quality gate, also run `bash <agent-dir>/hooks/aidlc-phase-quality-gate/aidlc-phase-quality-gate.sh`. Exit 2 is a gate failure with the code it names.
- Before `task-implementer` runs on tier 2 or 3, `PLAN_CHECK.md` must end with `## PLAN CHECK PASSED` (run `/plan-check`). On Claude Code the pre-write hook enforces this; elsewhere, check it yourself and stop if it is missing.

## Phase 1 — Load Pipeline

Resolve path from `/run-pipeline <role>/<pipeline-name>` to `.claude/pipelines/<role>/<pipeline-name>.pipeline.yaml`. Parse YAML to extract `steps`, `gates`, and `output`. Load gate profile from `.claude/config/gate-config.json` (default: `standard`). If `--resume`, read `pipeline-state-<pipeline-name>.json` and continue from the first non-completed step.

## Phase 2 — Execute Steps

Build a dependency graph from `depends_on` fields. Execute in topological order:

```
for each step in order:
  1. Verify all depends_on steps are completed
  2. Interpolate args ($INPUT → user input, $<step-id>.output → output path)
  3. Invoke the skill, capture output artifact path
  4. Evaluate gate if present:
     - PASS → continue
     - FAIL + on_fail: stop → halt pipeline
     - FAIL + on_fail: auto_recover → invoke recovery skill
     - FAIL + on_fail: hitl → pause for human decision
  5. Update pipeline-state.json (status, output, timestamps)
```

**Gate types:**

| Type | Behavior |
|------|----------|
| `decision` | Evaluate `pass_condition` against step output |
| `quality` | Invoke `/quality-gate` with transition type |
| `hitl` | Pause for human approval |

**HITL handling:** With a track root, publish the checkpoint block from Phase 0 and stop; the approval guard records the decision. Without one (legacy mode), display what was produced, present the gate description, and ask for APPROVE / APPROVE WITH CONDITIONS / REJECT / DEFER. Approve continues, reject stops, defer saves state for later resume.

## Phase 3 — State Management

Write `.claude/pipelines/pipeline-state-<pipeline-name>.json` (with a track root: `<track root>/runs/<pipeline-name>-<YYYYMMDDHHMM>.json`, adding `phase`, `tier`, `risk_levels` and `hd_refs`; `state.md` is the human view of the same state):

```json
{
  "pipeline": "<role>/<pipeline-name>",
  "input": "<original user input>",
  "started_at": "<timestamp>",
  "updated_at": "<timestamp>",
  "gate_profile": "standard",
  "status": "in_progress|completed|failed",
  "total_steps": 8,
  "completed_steps": 3,
  "steps": {
    "<step-id>": {
      "status": "completed|in_progress|pending|failed|skipped",
      "skill": "<skill-name>",
      "started_at": "<timestamp>",
      "completed_at": "<timestamp>",
      "output": "<artifact path>",
      "gate_result": "pass|fail|hitl_approved|hitl_rejected"
    }
  }
}
```

On `--resume`: read the state file, find the first non-completed step, continue.

## Phase 4 — Output

Show progress during execution (`✓` done, `●` running, `○` pending). On completion, display summary with artifacts and suggest `output.next_pipeline` if defined.

## Dry Run Mode

With `--dry-run`: parse the YAML, display the step chain with gates, but execute nothing.

```
Pipeline: product-owner/feature-intake (DRY RUN)
Steps:
  1. quick-assess  → /feature-balance-sheet quick $INPUT
     Gate: decision → stop on fail
  2. write-spec    → /spec-gen $INPUT (depends on: quick-assess)
  3. validate-spec → /quality-gate spec-to-plan
     Gate: quality → auto-recover with /spec-evolve
  4. briefing      → /gate-briefing  (Gate: HITL)
Artifacts: spec.md, feature-balance-sheet.md
Next: architect/design-to-plan
```

## Error Handling

- **Skill not found:** Mark step as failed, stop pipeline.
- **Gate failure with no recovery:** Stop pipeline, display failure reason.
- **User cancels:** Save current state for later resume.
