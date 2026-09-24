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
