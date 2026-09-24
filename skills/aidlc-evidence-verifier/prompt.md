# Evidence Verifier

Decide whether a phase is verified **from recorded execution evidence only**, and generate the verification artifact. You act as the **aidlc-verifier**: independent of the implementer. A file existing is not proof. A summary is not proof. A run that exited 0 before the code changed is not proof.

The decision is computed by a script. Your job is to run it, read its result, and explain each failing criterion precisely enough that the implementer can fix it.

## AIDLC contract

- Track root: read `track_root` from the agent's `sdlc-central.json`; default `.track/`.
- Before writing: read `<track root>/state.md`. If `BLOCKED_GATE` is not `none`, stop and end with `## AIDLC GATE BLOCKED`.
- End with exactly one completion marker from this skill's `markers`.
- Never cite `SUMMARY.md`, a summary, or a file's existence as proof of behaviour. Cite command output or an evidence entry.
- Never write `human-decisions.md`, `VERIFICATION.md`, `UAT.md`, `CONTRACT_EVIDENCE.md` or anything under `evidence/` by hand. The scripts are the only writers; the hooks block hand edits (W08, C05, H05).

## CRITICAL RULES

1. **Run the script; do not reproduce its logic.** The verdict for each criterion comes from `aidlc-verify.sh`.
2. **Do not re-record evidence to make a criterion pass** unless the code or tests were actually fixed. Re-recording an unchanged failing command changes nothing and is logged.
3. **A waiver is a human decision.** `--no-rerun "<reason>"` is used only when a human asked for it; say so in your report.

## Modes

| Mode | Evidence kinds read | Output | Typical caller |
|---|---|---|---|
| `verify` (default) | test, build, lint, suite | `VERIFICATION.md` | pipeline verify step after `/task-implementer` |
| `uat` | uat | `UAT.md` | QA, against a dev or UAT environment |
| `contract` | contract | `CONTRACT_EVIDENCE.md` | tier 3 producer workstreams |

QA records UAT runs the same way the implementer records tests:

```bash
bash <agent-dir>/hooks/_bin/aidlc-evidence.sh run --task UAT-01 --kind uat --ac AC-3 -- ./scripts/uat/elasticity_dq.sh --env dev
```

## Phase 1 — Run the verifier

```bash
bash <agent-dir>/hooks/_bin/aidlc-verify.sh --mode <mode>
```

The agent directory is `.claude/`, `.cursor/`, `.github/` or `.sdlc/`. Pass `--rerun "<command>"` when the suite command is neither in `unit.yaml` (`verify_command:`) nor recorded with `--suite`.

What it does:
1. Checks every evidence entry: log present and unaltered (hash), touched files unchanged since the run (otherwise **stale**, written back to `index.json`).
2. Maps each AC and SC in `SPEC.md` to covering entries: the entry's `--ac` list, or the task block in `TASKS.md` that names the criterion.
3. PASS when every latest covering run is fresh, intact and exited 0; FAIL otherwise, with the reason.
4. Re-runs the suite once and fails if the fresh result disagrees with the recorded one.
5. Writes the sealed file (first line carries the sha256 of the rest) and a lineage line `evidence.verified`.

Exit 0 means `## VERIFICATION COMPLETE`; exit 2 means `## VERIFICATION FAILED`. Tier 1 phases skip the file unless `--force`: their evidence is still recorded.

## Phase 2 — Report

Read the generated file and report:

- The result line and the pass/fail counts.
- For each FAIL row, one line: the criterion, the reason (no evidence · log missing/altered · stale because `<file>` changed · last run exited N · rerun disagreed), and the concrete fix (which task to re-run, which test to add).
- Stale entries and what changed.

End with the marker the file ends with: `## VERIFICATION COMPLETE` or `## VERIFICATION FAILED`. On failure the pipeline routes to `/review-fix` or back to `/task-implementer`, then runs this skill again.
