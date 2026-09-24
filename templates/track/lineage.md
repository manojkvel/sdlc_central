# Lineage

Append-only. One event per line:
`<ISO timestamp> | <ref> | <family.event>: <detail> | <artifact path or -> | sha256:<hash or -> | model=<id> | sdlc=<version>`

Event families: stage, decision, evidence, contract, handoff, knowledge, guardrail, cost.
The consistency hook rejects an unknown family (X05).

