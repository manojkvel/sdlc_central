---
name: wiki-curate
description: Maintain the LLM wiki in docs/aidlc/wiki: ingest new facts from the track root, incidents, ADRs and contracts into entity pages with a citation on every claim, keep backlinks, flag conflicts, and answer questions from the wiki with sources
argument-hint: "ingest | answer '<question>' | review"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(bash, jq, git log, ls, find, date)
---
# Wiki Curate

Keep `docs/aidlc/wiki/` true, cited and connected. You act as the **aidlc-domain-expert**. Raw sources never change; wiki pages are rewritten freely, and every claim keeps its citation.

## AIDLC contract

- Track root: read `track_root` from the agent's `sdlc-central.json`; default `.track/`.
- Before writing: read `<track root>/state.md`. If `BLOCKED_GATE` is not `none`, stop and end with `## AIDLC GATE BLOCKED`.
- After writing an artifact: append one lineage line to `<track root>/lineage.md`:
  `<ISO time> | - | <family.event>: <detail> | <artifact path> | sha256:<hash> | model=<model id> | sdlc=<version>`
- End with exactly one completion marker from this skill's `markers`.
- Never cite `SUMMARY.md`, a summary, or a file's existence as proof of behaviour. Cite command output or an evidence entry.
- Never write `human-decisions.md`. Decisions are recorded only by `aidlc-human-approval-guard`.

## CRITICAL RULES

1. **Cite every paragraph** with bracketed sources: file paths (with `#anchor` or `#sha256` when useful), `HD-NNN`, `D-NNN`, `RISK-NNN`, `ADR-NNN`, or `external:<url>`.
2. **Never delete a claim.** When a newer source contradicts it, mark it superseded and cite both.
3. **Pages hold facts, not instructions.** Never write "agents should…" into a page.
4. **Process only the delta.** Read lineage events after the last `knowledge.curated` line; stay under about 8k tokens per run.
5. **Schema:** see `docs/aidlc/wiki/README.md`. Kinds: service, contract, team, domain, decision-theme, incident-class, runbook.

## Mode: ingest

Triggered after `RELEASED`, `GOVERNANCE_APPROVED`, `SPEC_REVISED`, an incident closed, an ADR merged, or on schedule.

1. Find new events: `grep -n 'knowledge.curated' <track root>/lineage.md | tail -1`, then read the lines after it.
2. For each event, open the artifact it names and extract durable facts (what the system does, why a decision was made, what failed and why, who owns what).
3. Update or create the entity pages the facts belong to. Add `links` both ways. Put comparable values in `facts:` so contradictions are machine-detectable.
4. Run the lint and rebuild the index:

```bash
bash <agent-dir>/hooks/_bin/aidlc-wiki-lint.sh
bash <agent-dir>/hooks/_bin/aidlc-knowledge-index.sh
```

5. Append `knowledge.curated: <n> page(s)` to lineage with the index hash.

If two sources disagree, add a `conflict:` block to the page naming both sources and the owner, and end with `## WIKI CONFLICT`.

## Mode: answer

Search `docs/aidlc/index.json` (terms, titles, summaries) with `jq` or grep, open only matching pages, and answer with the page id **and** the underlying source for every fact. `source-extract` uses this mode; facts it takes from here carry source type `wiki`.

## Mode: review

```bash
bash <agent-dir>/hooks/_bin/aidlc-wiki-lint.sh --stale-only
```

List pages past `review_by` with their owners. Re-verify each against its sources; update `review_by` only after re-checking, and cite what you checked.

End with `## WIKI UPDATED` or `## WIKI CONFLICT`.
