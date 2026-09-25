# Review — 04-hub-and-decisions

Reviewer persona: aidlc-security-standards-reviewer (self-review by the implementing agent; a human review is still required).

| Severity | Finding | Location | Status |
| --- | --- | --- | --- |
| HIGH | Registry status updates changed an approved contract's hash, so every status change read as an unapproved edit (X02) | hooks/_lib/track-parse.sh | fixed (registry-maintained fields excluded; real edits still detected; test) |
| HIGH | The installer copied only one library file, so the contract library never reached installed projects | adapters/_shared/hooks.sh | fixed (all _lib scripts installed; architect install test) |
| MEDIUM | A stakeholders.yaml inline comment leaked into the authorised people list and rejected a valid decider | aidlc-human-approval-guard.sh | fixed (comments stripped; test) |
| MEDIUM | A contract's test_command is a shell command from the hub; whoever runs `aidlc-contract.sh test` executes it in the producer repository | hooks/_bin/aidlc-contract.sh | accepted (edits to an approved contract are detected by X02; run contract tests in CI, not on laptops) |
| MEDIUM | People with push access can still hand-edit .track/human-decisions.md in git; the hooks only stop agents | .track/human-decisions.md | accepted (docs/aidlc/decision-bot.md: protect it with CODEOWNERS and branch rules) |
| MEDIUM | Hub-and-spoke is tested with synthetic repositories only, not a real second workstream | docs/aidlc/hub-and-spoke.md | accepted (validate on the first real consumer) |
| LOW | Stakeholder authorisation matches identities as exact strings | stakeholders.yaml | accepted (use GitHub logins or SSO ids exactly as the bot reports them) |
