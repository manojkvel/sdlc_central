## TASK-001 evidence recorder (hooks/_bin/aidlc-evidence.sh)
- covers AC-1
- Verify: `node --test tests/aidlc-phase2.test.js` (the phase suite; added 2026-09-25 when T07 was introduced)
## TASK-002 verifier (hooks/_bin/aidlc-verify.sh)
- covers AC-2, AC-3, AC-4, AC-5, AC-8, AC-9
- Verify: `node --test tests/aidlc-phase2.test.js` (the phase suite; added 2026-09-25 when T07 was introduced)
## TASK-003 guards and seal (W08, C05, H05)
- covers AC-6
- Verify: `node --test tests/aidlc-phase2.test.js` (the phase suite; added 2026-09-25 when T07 was introduced)
## TASK-004 skills and pipelines (task-implementer, aidlc-evidence-verifier, release-readiness-checker, quality-gate, feature-build, release-validation)
- covers AC-7
- Verify: `node --test tests/aidlc-phase2.test.js` (the phase suite; added 2026-09-25 when T07 was introduced)
