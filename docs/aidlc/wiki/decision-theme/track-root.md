---
id: wiki/decision-theme/track-root
kind: decision-theme
title: Where AIDLC artifacts live
owner: role/tech-lead
sources: [.track/decisions.md, docs/aidlc/design-invariants.md]
links: [wiki/domain/decision-vocabulary, wiki/service/approval-guard]
review_by: 2027-03-31
updated: 2026-09-25
facts:
  track_root_default: .track
---
Every AIDLC artifact lives under the track root, `.track/` by default, configurable through `track_root`; the name replaced the reference implementation's `.planning/` because the directory holds decisions, evidence, lineage and contracts as well as plans [.track/decisions.md].

Git is the only database for this record; hooks read nothing else and no hosted store is used [docs/aidlc/design-invariants.md].
