---
name: aidlc-decision-guard
description: Record a human gate decision through the approval guard on agents without a prompt hook, or audit the decision log for gates that were passed without an accepted, structured decision
argument-hint: "record '<decision string>' | audit"
allowed-tools: Read, Grep, Glob, Bash(bash, printf, jq, shasum, ls, find, date)
---
# Decision Guard

Gate decisions are recorded by one component only: `aidlc-human-approval-guard`. On Claude Code it runs automatically on every prompt. On other agents, and for audits, use this skill.

## AIDLC contract

- Track root: read `track_root` from the agent's `sdlc-central.json`; default `.track/`.
- Before writing: read `<track root>/state.md`. If `BLOCKED_GATE` is not `none`, stop and end with `## AIDLC GATE BLOCKED`.
- After writing an artifact: append one lineage line to `<track root>/lineage.md`:
  `<ISO time> | - | <family.event>: <detail> | <artifact path> | sha256:<hash> | model=<model id> | sdlc=<version>`
- End with exactly one completion marker from this skill's `markers`.
- Never cite `SUMMARY.md`, a summary, or a file's existence as proof of behaviour. Cite command output or an evidence entry.
- Never write `human-decisions.md`. Decisions are recorded only by `aidlc-human-approval-guard`.
- Never read `evidence/index.json`, `lineage.md` or `guardrail-log.md` whole; they grow with every run. Use `aidlc-evidence.sh summary` or `list`, the summary block at the top of `VERIFICATION.md` or `SCORECARD.md`, and `grep '<phase>' lineage.md | tail -20`.

## Mode: record

Pass the human's reply to the guard **verbatim**. Never rephrase it, never add a decision string the human did not type, never decide on their behalf.

```bash
printf '%s' '{"prompt": <the reply as a JSON string>}' \
  | bash <agent-dir>/hooks/aidlc-human-approval-guard/aidlc-human-approval-guard.sh --role "<their role>"
```

- Exit 0 with `DECISION RECEIPT HD-NNN`: show the receipt, end with `## DECISION RECORDED`.
- Exit 2: show the rejection (A01 vague, A02 wrong gate, A03 missing text, A04 not upper case) and the accepted strings; end with `## DECISION REJECTED`.
- Exit 0 without a receipt: the reply was discussion, not a decision. Answer it and restate the open checkpoint.

## Mode: audit

List gates that were passed without an accepted decision:

1. Read `gate-config.json`: for each phase in `<track root>/phases/`, the gate profile from its tier, and its `hitl_gates`.
2. For each gate the phase has passed (its stage in `state.md` or lineage is beyond the gate), find an HD record in `human-decisions.md` whose **Gate** and **Phase** match and whose **Status** is `APPROVED`, `APPROVED W/ RISK` or `BACKFILLED`.
3. Report missing records, records with `identity: asserted` at high, security-sensitive or release risk, and the count of blocked vague attempts (section 4).
4. Run `bash <agent-dir>/hooks/aidlc-artifact-consistency-check/aidlc-artifact-consistency-check.sh --all` and include its codes (X02 = an approved artifact changed after approval; X04 = a decision without lineage).

End with `## DECISION RECORDED` when nothing is missing, otherwise `## DECISION REJECTED` with the list.
