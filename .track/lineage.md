# Lineage

Append-only. One event per line:
`<ISO timestamp> | <ref> | <family.event>: <detail> | <artifact path or -> | sha256:<hash or -> | model=<id> | sdlc=<version>`

Event families: stage, decision, evidence, contract, handoff, knowledge, guardrail, cost.
The consistency hook rejects an unknown family (X05).

2026-09-24T18:39:55Z | - | stage.entered: intake | .track/state.md | sha256:- | model=none | sdlc=2.0.0-alpha
2026-09-24T18:39:55Z | - | stage.entered: execution | .track/phases/01-control-audit-rails/unit.yaml | sha256:71ee7d51475370a692baec35d336ca4664f9271795b5d6bc99693b3898c91b3e | model=claude-opus-5-5 | sdlc=2.0.0-alpha
2026-09-24T18:39:55Z | - | evidence.recorded: hook suite 80 passed | hooks/_test/run.sh | sha256:20dcc380e622f658dae4db5e52222b02a8a3e02d7095ed93732ee04d81407574 | model=claude-opus-5-5 | sdlc=2.0.0-alpha
2026-09-24T18:39:55Z | - | stage.entered: review | docs/aidlc/design-invariants.md | sha256:b7c8e8f873055196d49f410678ec81f48a1cd24608510222de9cd303f71f4bf9 | model=claude-opus-5-5 | sdlc=2.0.0-alpha
2026-09-24T18:40:06Z | - | stage.entered: review | .track/phases/01-control-audit-rails/unit.yaml | sha256:71ee7d51475370a692baec35d336ca4664f9271795b5d6bc99693b3898c91b3e | model=claude-opus-5-5 | sdlc=2.0.0-alpha
2026-09-24T18:54:02Z | - | stage.entered: execution | .track/phases/02-evidence-rail/unit.yaml | sha256:1cb9cfaab22f5864a508f804b61aa93abf8f5507dcb1fe26c434307d4608e71a | model=claude-opus-5-5 | sdlc=2.0.0-alpha
2026-09-24T18:54:02Z | - | stage.entered: verification | .track/phases/02-evidence-rail/unit.yaml | sha256:1cb9cfaab22f5864a508f804b61aa93abf8f5507dcb1fe26c434307d4608e71a | model=claude-opus-5-5 | sdlc=2.0.0-alpha
2026-09-24T18:54:11Z | - | evidence.reexecuted: exit=0 | .track/phases/02-evidence-rail/evidence/_verify/rerun-20260924T185402Z.out | sha256:d1fa1a5f4a1a9a7fbd6ccd128d23cba32c71211a84a2c8c2b575b1a79d4791a6 | model=unknown | sdlc=2.0.0-alpha
2026-09-24T18:54:11Z | - | evidence.verified: VERIFICATION.md FAILED | .track/phases/02-evidence-rail/VERIFICATION.md | sha256:6720ae385d025dde84b8b6add81aa047d941d941e08115ccd5f08bbcc62855cb | model=unknown | sdlc=2.0.0-alpha
2026-09-24T18:54:31Z | E-001 | evidence.recorded: TASK-003 test exit=0 | .track/phases/02-evidence-rail/evidence/index.json | sha256:012d7dfe9c87ceadb9466f75f4364f6cbee439893fd221773fd3e5eff214645e | model=unknown | sdlc=2.0.0-alpha
2026-09-24T18:54:43Z | E-002 | evidence.recorded: TASK-004 test exit=0 | .track/phases/02-evidence-rail/evidence/index.json | sha256:b89c2280b214593fb7615722de5db00cd9456f08ee4d1368b03221097363fd71 | model=unknown | sdlc=2.0.0-alpha
2026-09-24T18:54:54Z | E-003 | evidence.recorded: TASK-002 test exit=0 | .track/phases/02-evidence-rail/evidence/index.json | sha256:8956504e153cd086f1faadbf935eb7582fb302b16051e7ed7ad0efec0b4fa10c | model=unknown | sdlc=2.0.0-alpha
2026-09-24T18:54:56Z | E-004 | evidence.recorded: TASK-001 test exit=0 | .track/phases/02-evidence-rail/evidence/index.json | sha256:e694e2724c23c17c6d23cbc1ee776b04bfe5695881347f040d846003602771e9 | model=unknown | sdlc=2.0.0-alpha
2026-09-24T18:55:14Z | - | evidence.reexecuted: exit=0 | .track/phases/02-evidence-rail/evidence/_verify/rerun-20260924T185505Z.out | sha256:74dd4919045353e9d9698a2c855ed47589282fe8540d73fae78d7be5265f45f5 | model=unknown | sdlc=2.0.0-alpha
2026-09-24T18:55:14Z | - | evidence.verified: VERIFICATION.md COMPLETE | .track/phases/02-evidence-rail/VERIFICATION.md | sha256:9bdec5f4f81aaf31bc3c59829def79b1bb65d4432a6d638a582fb2db50fd5ebf | model=unknown | sdlc=2.0.0-alpha
2026-09-24T18:55:34Z | - | stage.entered: review | .track/phases/02-evidence-rail/unit.yaml | sha256:1cb9cfaab22f5864a508f804b61aa93abf8f5507dcb1fe26c434307d4608e71a | model=claude-opus-5-5 | sdlc=2.0.0-alpha
