# AIDLC wiki

What the organisation knows, curated from immutable sources. Raw sources (the track root,
lineage, decisions, incidents, ADRs, contracts, code) never change; these pages are rewritten
freely by `wiki-curate`, and every claim cites a raw source so a reader can always drop one level.

## Page schema

`docs/aidlc/wiki/<kind>/<slug>.md`, kinds: `service`, `contract`, `team`, `domain`,
`decision-theme`, `incident-class`, `runbook`.

```markdown
---
id: wiki/domain/decision-vocabulary
kind: domain
title: Decision vocabulary
owner: role/tech-lead
sources: [docs/aidlc/hooks.md, hooks/aidlc-human-approval-guard/aidlc-human-approval-guard.sh]
links: [wiki/decision-theme/track-root]
review_by: 2027-03-31
updated: 2026-09-25
facts:
  casual_approval_allowed_at: low
---
Each paragraph cites at least one source in brackets [docs/aidlc/hooks.md].
```

Rules enforced by `hooks/_bin/aidlc-wiki-lint.sh` (L01-L08): required frontmatter, known kind,
every paragraph cited, sources resolve, no orphan pages, no page past `review_by`, no two pages
asserting different values for the same `facts:` key, no link to a missing page.
Pages hold facts, never instructions to agents.
