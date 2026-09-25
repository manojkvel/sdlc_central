# Token economics

Enforcement runs as shell, so it costs no model tokens. The model pays only for what it loads:
skill and persona prompts, artifacts it reads, and the short messages hooks feed back.

## Where tokens go (estimates from file sizes, characters / 4)

| Loaded | Tokens |
| --- | --- |
| New AIDLC skill prompt, when invoked | 700 to 1,500 |
| Growth of modified skills (task-implementer, quality-gate, plan-gen, spec-gen, release-readiness) | 100 to 700 each |
| Pipeline runner | about 2,300 |
| One persona as a subagent | about 550 plus its own fresh context |
| Tier 2 phase artifacts (SPEC, PLAN, VERIFICATION, SCORECARD, REVIEW) | 900 to 1,900 in total, only when read |
| Block message / decision receipt / open-gate reminder | about 60 / 150 / 120 (reminder once per checkpoint) |
| Evidence run output | last 25 lines, usually less than the raw test output it replaces |

Estimated overhead for a tier 2 unit: 10,000 to 12,000 tokens, roughly 8 to 12 percent of a
full-pipeline run. Tier 1 adds almost nothing. Replace these estimates with measurements (below).

## Rules that keep it there

1. **Never read growing logs whole.** `evidence/index.json`, `lineage.md` and `guardrail-log.md`
   grow with every run. Agents use `aidlc-evidence.sh summary|list`, the summary blocks of
   `VERIFICATION.md` and `SCORECARD.md`, and `grep '<phase>' lineage.md | tail -20`. The rule is in
   the shared AIDLC contract carried by every skill and persona, and in the runner.
2. **Keep the index small.** Touched-file lists live in per-run manifests
   (`evidence/<TASK>/<NNN>-touched.tsv`); the index holds one hash and a count per run.
   `aidlc-evidence.sh compact` migrates older entries. In this repo that took the phase 2 index
   from about 24,600 tokens to 1,100.
3. **Remind once.** The approval guard's open-gate note is shown once per checkpoint
   (`GATE_REMINDED` in the resume block), not on every turn.
4. **Scripts decide, models explain.** Verification, the scorecard, traceability, metrics, lint and
   the console are computed by scripts; skills only run them and explain failures.

## Measuring real usage

On Claude Code, the Stop hook runs `hooks/_bin/aidlc-usage.sh`. It reads only the transcript lines
added since its last run, counts each response once (a response is split over several transcript
lines that repeat the same usage), and adds input, output, cache-read and cache-creation tokens to
the current phase in `<track root>/runs/usage/<session>.json`. `aidlc-metrics.sh` reports:

- `cost.tokens_total` and its components, the number of sessions and responses;
- `cost.per_tier`: average tokens per unit of work for each tier;
- `phases[].tokens`: usage per phase.

Cache reads dominate long sessions and are billed at a fraction of input; report the components,
not only the total. Other agents do not expose usage, so their cost stays `null`.

## Encodings and output styles

- **TOON (Token-Oriented Object Notation).** Saves tokens when a model reads large uniform JSON
  arrays. Here, models are not meant to read JSON at all: scripts read the index, and the agent sees
  one-line summaries. The markdown tables the framework writes are already about as compact as
  TOON's tabular form. Not adopted.
- **Terse "caveman" output.** Cuts output tokens, which cost more than input, but the artifacts are
  audit records read by product owners, release managers and auditors, and the decision strings and
  receipts must be exact. Not adopted for artifacts, checkpoints or receipts. An agent may still use a
  terse style in its own working chatter; the framework does not depend on it.
