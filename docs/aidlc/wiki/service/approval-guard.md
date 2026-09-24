---
id: wiki/service/approval-guard
kind: service
title: Approval guard
owner: role/tech-lead
sources: [hooks/aidlc-human-approval-guard/aidlc-human-approval-guard.sh, docs/aidlc/design-invariants.md]
links: [wiki/domain/decision-vocabulary, wiki/decision-theme/track-root]
review_by: 2027-03-31
updated: 2026-09-25
facts:
  casual_approval_allowed_at: low
---
The approval guard is the only component that writes `human-decisions.md`; it records an HD record with artifact hashes, a lineage line, a risk entry when a risk is accepted, and a state update, and prints a decision receipt [hooks/aidlc-human-approval-guard/aidlc-human-approval-guard.sh].

Agents, skills and shell commands are blocked from writing the decision log by codes W07 and C04 [docs/aidlc/design-invariants.md].
