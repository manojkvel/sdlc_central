# Review — 03-governance-knowledge

Reviewer persona: aidlc-security-standards-reviewer (self-review by the implementing agent; a human review is still required).

| Severity | Finding | Location | Status |
| --- | --- | --- | --- |
| HIGH | Verifier passed every criterion when a jq error hit the coverage lookup (fail-open) | hooks/_bin/aidlc-verify.sh | fixed (phase 2: fail closed, with test) |
| HIGH | Catalog file was duplicated by an insert helper returning None for the last name | registry/catalog.yaml | fixed (registry integrity tests added) |
| HIGH | Evidence could be recorded for a command that masks its exit code (`; exit 0`), and one such entry (E-003) was recorded during this phase | hooks/_bin/aidlc-evidence.sh, aidlc-verify.sh | fixed (recorder refuses; verifier excludes and lists E-003 as rejected) |
| MEDIUM | Piped commands (`test | tail`) took the last command's exit code | aidlc-evidence.sh, aidlc-verify.sh | fixed (pipefail, with test) |
| MEDIUM | Persona write manifests are prompt-enforced only; hooks cannot identify the writing persona (H04 reserved) | agents/*, hooks | accepted (documented in docs/aidlc/personas.md) |
| MEDIUM | Seals are tamper-evident, not signatures; a forged file with a recomputed seal needs matching index entries and fails the CI re-run | VERIFICATION.md, SCORECARD.md | accepted (documented in docs/aidlc/evidence.md) |
| MEDIUM | High and release decisions carry asserted identity until the decision bot exists | aidlc-human-approval-guard, scorecard D3 | accepted (advisory in D3; phase 4) |
| LOW | Exit-code masking detection is pattern-based; other forms (for example `cmd || echo`) are not caught | aidlc-evidence.sh | accepted (review evidence commands at the plan gate) |
| LOW | Console decision write path is absent; the console is read-only | console/console.html | accepted (phase 4) |
