---
name: aidlc-metrics-extract
description: Compute AIDLC-native and DORA metrics from the track root — lead time by stage, rework, evidence coverage, structured approval rate, approval latency, guardrail blocks, scorecard first-pass rate — into metrics.json and CSVs, each squad against its own baseline
argument-hint: "[--out docs/aidlc/metrics] [--squad <name>]"
allowed-tools: Read, Grep, Glob, Bash(bash, jq, bc, ls, find, date)
---
# AIDLC Metrics Extract

Produce the squad's delivery metrics from the artifacts the framework already writes. Nothing is surveyed or self-reported.

## AIDLC contract

- Track root: read `track_root` from the agent's `sdlc-central.json`; default `.track/`.
- Before writing: read `<track root>/state.md`. If `BLOCKED_GATE` is not `none`, stop and end with `## AIDLC GATE BLOCKED`.
- After writing an artifact: append one lineage line to `<track root>/lineage.md`:
  `<ISO time> | - | <family.event>: <detail> | <artifact path> | sha256:<hash> | model=<model id> | sdlc=<version>`
- End with exactly one completion marker from this skill's `markers`.
- Never cite `SUMMARY.md`, a summary, or a file's existence as proof of behaviour. Cite command output or an evidence entry.
- Never write `human-decisions.md`. Decisions are recorded only by `aidlc-human-approval-guard`.

## CRITICAL RULES

1. **Run the script; never estimate a number.** A metric whose source does not exist is `null` and is reported as "not measured yet".
2. **Counts beside rates.** Every rate you quote carries its numerator and denominator (for example "structured approval rate 0.86 (12 of 14)").
3. **Never rank squads.** Compare a squad only with its own `baseline.json`. Report cohorts by the month the squad adopted AIDLC so the learning dip is visible.
4. **Gates are not trends.** Traceability, evidence completeness and decision-ledger completeness are gates (100 percent or no release); do not chart them as targets.

## Run

```bash
bash <agent-dir>/hooks/_bin/aidlc-metrics.sh [--out docs/aidlc/metrics] [--squad <name>]
```

| Output | Content |
|---|---|
| `metrics.json` | `dora` (releases, deployment frequency, lead time, change failure rate, time to restore), `governance` (structured approval rate, vague attempts, asserted identities, approval latency by gate, guardrail blocks), `quality` (evidence coverage, rework rate, scorecard first-pass rate), `cost` (tokens, best effort), `models`, and per-phase detail |
| `phases.csv`, `decisions.csv`, `guardrails.csv` | Flat rows for BI tools |

Change failure rate and time to restore need `<track root>/incidents.json` (written by `incident-triager`: `{"incidents":[{"id","phase","opened_at","restore_hours"}]}`). The squad's baseline lives in `<track root>/baseline.json` (`{"lead_time_days":..,"rework_rate":..,"recorded_at":..,"source":..}`), recorded once before adoption.

## Report

Summarise in five lines at most: lead time against baseline, where time goes by stage, rework, evidence coverage, and approval latency. Name the one bottleneck the numbers show. End with `## METRICS READY`.
