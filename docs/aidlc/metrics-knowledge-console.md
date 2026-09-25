# Metrics, knowledge and the console

All three read the track root and write files. Nothing runs as a service.

## Metrics — `aidlc-metrics.sh` (skill `/aidlc-metrics-extract`)

`docs/aidlc/metrics/metrics.json` plus `phases.csv`, `decisions.csv`, `guardrails.csv`.

| Group | Metrics | Source |
| --- | --- | --- |
| DORA | releases, deployment frequency, lead time median, change failure rate, time to restore | lineage `stage.entered: released`; `incidents.json` (null until it exists) |
| Speed | lead time and days per stage, per phase | lineage `stage.entered` events |
| Quality | evidence coverage, rework rate, scorecard first-pass rate | VERIFICATION.md, human-decisions.md, gate-history.json |
| Governance | structured approval rate (with counts), vague attempts, asserted identities, approval latency per gate, guardrail blocks | human-decisions.md, lineage, guardrail-log.md |
| Cost | tokens by component, per phase and per tier | runs/usage/*.json from the Claude Code Stop hook (`aidlc-usage.sh`); null on other agents |

Rules: a missing source gives `null`, never zero; every rate carries its counts; each squad is
compared only with its own `baseline.json`; squads are never ranked.

## Knowledge — wiki, lint, index

- `docs/aidlc/wiki/` pages (schema in its README), curated by `/wiki-curate`, every paragraph cited.
- `aidlc-wiki-lint.sh`: L01-L08 (frontmatter, kind, uncited paragraph, unresolved source, orphan,
  past review date, contradictory facts, dangling link); `--stale-only` writes `## Stale knowledge`
  into state.md.
- `aidlc-knowledge-index.sh`: `docs/aidlc/index.json` with pages, phases and decisions, which
  `/source-extract` and the console search.
- The source graph (SCIP index + MCP server) is deferred to phase 4 or later.

## Console — `aidlc-portfolio.sh` + `aidlc-console.sh`

1. `aidlc-portfolio.sh` writes `docs/aidlc/console-data/` (portfolio, checkpoints, decisions,
   guardrails, and copies metrics and index). `--merge <out> <dir>...` combines repos for a department.
2. `aidlc-console.sh` inlines that data into `console/console.html` and writes
   `docs/aidlc/console/index.html`: one self-contained file, no backend, no network.

Views: Portfolio, Unit of work, Decision console (open checkpoints with the accepted decision
strings, SLA age, artifact hashes; history), Governance, Metrics (grouped by speed, quality,
reliability, governance, cost, against the squad's own baseline), Knowledge (search).
The console is read-only in phase 3; recording decisions from it arrives with the decision bot in phase 4.

## Operations

- `aidlc-integrity.sh` verifies the installed hooks against the manifest written at install (I02)
  and that Claude Code still wires them (I03).
- `aidlc-sla.sh` escalates a gate open longer than `stakeholders.yaml` allows (S02).
- `setup/install-ci.sh` installs `.github/workflows/aidlc-checks.yml`: per pull request, integrity,
  phase quality gate, consistency, traceability, wiki lint, then metrics, index and portfolio as
  an artifact; on a weekday schedule, SLA and stale knowledge.
