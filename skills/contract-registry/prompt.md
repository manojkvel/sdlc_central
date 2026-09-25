# Contract Registry

Coordinate workstreams through explicit, approved contracts. **Golden rule:** no consumer builds against an unapproved producer contract unless the risk is accepted in writing, and then its release claims are excluded until the contract is verified.

## AIDLC contract

- Track root: read `track_root` from the agent's `sdlc-central.json`; default `.track/`.
- Before writing: read `<track root>/state.md`. If `BLOCKED_GATE` is not `none`, stop and end with `## AIDLC GATE BLOCKED`.
- After writing an artifact: append one lineage line to `<track root>/lineage.md`:
  `<ISO time> | - | <family.event>: <detail> | <artifact path> | sha256:<hash> | model=<model id> | sdlc=<version>`
- End with exactly one completion marker from this skill's `markers`.
- Never cite `SUMMARY.md`, a summary, or a file's existence as proof of behaviour. Cite command output or an evidence entry.
- Never write `human-decisions.md`. Decisions are recorded only by `aidlc-human-approval-guard`.
- Never read `evidence/index.json`, `lineage.md` or `guardrail-log.md` whole; they grow with every run. Use `aidlc-evidence.sh summary` or `list`, the summary block at the top of `VERIFICATION.md` or `SCORECARD.md`, and `grep '<phase>' lineage.md | tail -20`.
- Never edit `contracts/*.md`, `contract-registry.md` or `dependency-map.md` by hand; the registry tool writes them.

## The lifecycle

```
DRAFT ──APPROVE WORKSTREAM CONTRACT WITH RISK: WS-NNN - <risk>──▶ APPROVED_WITH_RISK   consumers may build; release claims excluded
DRAFT ──APPROVE WORKSTREAM CONTRACT: WS-NNN - <ack> + green test──▶ APPROVED
APPROVED_WITH_RISK ──green test──▶ APPROVED   → consumers: propose-lift → LIFT EXCLUSION: WS-NNN - <ack>
APPROVED ──red test──▶ BREACHED ──green test──▶ APPROVED   (consumers blocked while BREACHED)
```

## In the hub

```bash
T=<agent-dir>/hooks/_bin/aidlc-contract.sh
bash $T init
bash $T workstream WS-001 --name Data --repo ../data-repo --owner "Helen T"
bash $T register C-001 --kind data --producer WS-001 --consumers WS-002,WS-004 \
   --schema schemas/elasticity.expectations.json --test "bash scripts/check_c001.sh" --description "grain, freshness, DQ"
bash $T request-approval C-001      # publishes the approve-contract checkpoint; the architect replies
bash $T approve C-001               # applies the recorded decision (and runs the test for a plain approval)
bash $T test --all                  # run on a schedule and on every producer merge
```

The contract's `test_command` runs in the producer repository (its path comes from `workstream-map.md`). It must fail when the producer stops meeting the contract: for data, an expectation suite against the produced table; for an API, a schema conformance test against the OpenAPI document.

## In a consumer

The phase's `unit.yaml` names the hub and the contracts:

```yaml
id: UOW-004
name: elasticity-api
workstream: WS-002
tier: 3
hub: ../forecasting-hub
consumes: [C-001]
produces: [C-002]
```

```bash
bash $T check          # 0 approved · 3 building on risk-accepted contracts (sets release_claims_excluded) · 2 blocked
bash $T propose-lift   # when every consumed contract is APPROVED: publishes the lift-exclusion checkpoint
```

The pre-write guard runs the same check before any source write (W09), and the scorecard's D5 fails while a contract is unapproved or the unit's release claims are excluded.

## Report

State each contract's id, producer, consumers, status, deciding HD and last test. End with `## CONTRACT OK` when the requested operation succeeded and nothing the user depends on is DRAFT or BREACHED, otherwise `## CONTRACT BLOCKED` with the reason.
