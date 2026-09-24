# AIDLC evidence rail

Evidence beats assertions. A phase is verified only by recorded runs of real commands whose
output is intact and whose inputs have not changed since. Summaries, reports and file
existence never count.

## Record: `aidlc-evidence.sh`

```bash
bash <agent-dir>/hooks/_bin/aidlc-evidence.sh run --task TASK-003 --ac AC-2,AC-3 -- npm test -- auth
bash <agent-dir>/hooks/_bin/aidlc-evidence.sh run --task TASK-003 --suite -- npm test
bash <agent-dir>/hooks/_bin/aidlc-evidence.sh run --task UAT-01 --kind uat --ac AC-3 -- ./scripts/uat/check.sh --env dev
bash <agent-dir>/hooks/_bin/aidlc-evidence.sh list
```

| Option | Meaning |
| --- | --- |
| `--task` | Required. The task (or UAT case) the run belongs to |
| `--ac` | Criteria the run proves; otherwise taken from the task's block in `TASKS.md` |
| `--kind` | `test` (default), `build`, `lint`, `uat`, `contract` |
| `--suite` | Marks the full suite run the verifier re-executes |
| `--report` | Attach a machine-readable report (JUnit XML, JSON) |
| `--files` | Touched files; default is the working-tree changes outside the track root |

Each run writes `evidence/<TASK>/<NNN>-<slug>.out|.err` (gitignored bodies) and an entry in
`evidence/index.json` (committed): command, exit code, timings, output hashes, touched files and
their hashes. The recorder exits with the command's exit code.

## Verify: `aidlc-verify.sh`

```bash
bash <agent-dir>/hooks/_bin/aidlc-verify.sh [--mode verify|uat|contract] [--rerun "<cmd>"] [--no-rerun "<reason>"]
```

For each AC and SC in `SPEC.md`:

| Result | When |
| --- | --- |
| PASS | every latest covering run is intact, fresh and exited 0 |
| FAIL — no evidence | nothing covers the criterion (also the result of any error computing coverage) |
| FAIL — log missing / altered | the output file is gone or its hash changed |
| FAIL — stale | a file the run touched changed after the run; `index.json` is updated with `stale: true` |
| FAIL — last run exited N | the latest run of a covering command failed |

Then it re-runs the suite once (`--rerun`, else `verify_command:` in `unit.yaml`, else the latest
`--suite` entry). A fresh failure, or a recorded failure, fails the RERUN row. With no suite command
the RERUN row fails unless a human waiver is passed with `--no-rerun "<reason, citing the HD record>"`.

The output (`VERIFICATION.md`, `UAT.md` or `CONTRACT_EVIDENCE.md`) starts with
`<!-- generated-by: aidlc-evidence-verifier sha256:<hash of the rest> -->`. The hygiene hook
recomputes the seal (H05); the pre-write and command guards block hand writes (W08, C05).
Tier 1 phases record evidence but skip the file.

## Where it is enforced

| Point | Check |
| --- | --- |
| `feature-build` pipeline | `verify-evidence` step between `implement` and `verify-spec`; failure auto-recovers with `review-fix` |
| `qa/release-validation` | `uat-evidence` step writes `UAT.md` before readiness |
| `release-readiness-checker` | "Execution evidence" is a Required check: sealed, complete, no stale entries |
| `aidlc-final-verification` hook | `git tag`, deploy and release-ready claims blocked on F01 (verification) and F04 (stale) |

## Known limits

- Log bodies are gitignored, so full integrity checks run where the work was done. CI relies on the
  committed index, the seal, and its own re-run of the suite.
- The seal detects edits; it is not a signature. A forged file with a recomputed seal would still
  need matching index entries and would fail the CI re-run.
