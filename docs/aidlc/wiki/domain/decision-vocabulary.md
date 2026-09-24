---
id: wiki/domain/decision-vocabulary
kind: domain
title: Decision vocabulary
owner: role/tech-lead
sources: [docs/aidlc/hooks.md, hooks/aidlc-human-approval-guard/aidlc-human-approval-guard.sh, config/gate-config.json]
links: [wiki/decision-theme/track-root, wiki/service/approval-guard]
review_by: 2027-03-31
updated: 2026-09-25
facts:
  casual_approval_allowed_at: low
  decision_strings_case: upper
---
A gate decision is the first line of a human reply and must be one of a closed set of upper-case strings, such as APPROVE PLAN, APPROVE WITH RISK with its reason, REQUEST CHANGES with its reason, or DEFER [docs/aidlc/hooks.md].

Casual replies such as "ok" are recorded as the gate's approval only at low risk; at medium risk and above they are rejected with code A01 and logged [config/gate-config.json] [hooks/aidlc-human-approval-guard/aidlc-human-approval-guard.sh].

High and security-sensitive gates need a risk acknowledgement after a colon, and release gates need the release scope [hooks/aidlc-human-approval-guard/aidlc-human-approval-guard.sh].
