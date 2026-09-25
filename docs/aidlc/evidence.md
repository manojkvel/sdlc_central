# AIDLC evidence rail

Evidence beats assertions. A phase is verified only by recorded runs of real commands whose
output is intact and whose inputs have not changed since. Summaries, reports and file
existence never count.

## Record: `aidlc-evidence.sh`

```bash
bash <agent-dir>/hooks/_bin/aidlc-evidence.sh run --task TASK-003 --ac AC-2,AC-3 -- npm test -- auth
bash <agent-dir>/hooks/_bin/aidlc-evidence.sh run --task TASK-003 --suite -- npm test
bash <agent-dir>/hooks/_bin/aidlc-evidence.sh run --task UAT-01 --kind uat --ac AC-3 -- ./scripts/uat/check.sh --env dev
bash <agent-dir>/hooks/_bin/aidlc-evidence.sh list        # latest run per command, one line each (--all for every run)
bash <agent-dir>/hooks/_bin/aidlc-evidence.sh summary     # counts, plus failing and stale runs only
bash <agent-dir>/hooks/_bin/aidlc-evidence.sh compact     # migrate old entries that carried inline touched-file lists
```

| Option | Meaning |
| --- | --- |
| `--task` | Required. The task (or UAT case) the run belongs to |
| `--ac` | Criteria the run proves; otherwise taken from the task's block in `TASKS.md` |
| `--kind` | `test` (default), `build`, `lint`, `uat`, `contract` |
| `--suite` | Marks the full suite run the verifier re-executes |
| `--report` | Attach a machine-readable report (JUnit XML, JSON) |
| `--files` | Touched files; default is the working-tree changes outside the track root |

Each run writes `evidence/<TASK>/<NNN>-<slug>.out|.err` (gitignored bodies), a manifest
`evidence/<TASK>/<NNN>-touched.tsv` of touched files and their hashes (committed), and one small
entry in `evidence/index.json` (committed): command, exit code, timings, output hashes, touched count,
manifest path and hash. The recorder exits with the command's exit code, refuses commands that mask
it, and runs with pipefail. Agents read the index through `list` and `summary`, never whole.

## Test first: `--red`

A passing test proves a change only if the same test failed before it. Before changing code for a
task, record its new test with `--red`:

```bash
bash <agent-dir>/hooks/_bin/aidlc-evidence.sh run --task TASK-003 --red -- npm test -- reset
```

- The run must fail. The recorder exits 0 with `RED confirmed`. If the test already passes, it exits 3:
  the test proves nothing and must be rewritten.
- Red runs are stored with `"expect": "fail"`. They never count as coverage, never make a criterion
  fail, and are left out of the "latest failing" count in `summary`.
- With `red_green_required: true` in `gate-config.json` (the default), or `red_green: required` in
  `unit.yaml`, the verifier adds a **Test-first proof** table. Each task in `TASKS.md` passes only when
  a red run for that task comes before its latest passing run. A task whose block says
  `Red: n/a - <reason>` or `Verify: n/a - <reason>` is listed as WAIVED with the reason, for a reviewer
  to judge.
- Every task in `TASKS.md` needs a `Verify:` line naming the command that proves it (T07).

Credit: the rule follows the red-green discipline in obra/superpowers (test-driven-development) and
the verify-before-code idea in Get Shit Done. No text was copied.

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
| FAIL — manifest missing / altered | the touched-file manifest is gone or its hash changed |
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
