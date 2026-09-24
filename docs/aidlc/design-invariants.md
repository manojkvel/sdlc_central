# AIDLC design invariants

Every change to the AIDLC extension is checked against this list. Each invariant names
the test that enforces it. A change that needs to break one is proposed as a gate
decision (`APPROVE WITH RISK: <reason>`) and this file is updated in the same pull request.

Sources: [AIDLC Framework PRD](https://claude.ai/code/artifact/616a5892-9810-42b6-99d6-77fd7f31557a) ·
[AIDLC Conversion Technical Guide](https://claude.ai/code/artifact/bb73da70-0527-40b6-b78c-cc86f59b44a0)

| # | Invariant | Enforced by |
| --- | --- | --- |
| 1 | Git is the only database. Every AIDLC artifact lives under the track root (default `.track/`) or `docs/aidlc/`. | Hooks read nothing else; review |
| 2 | No hook or skill needs a running process, network access or a model call to enforce a rule. | `tests/aidlc-phase1.test.js` "makes no network or model calls" |
| 3 | Only `aidlc-human-approval-guard` writes `human-decisions.md`. Agents, skills and shell commands cannot. | W07, C04, and the test "only the approval guard writes human-decisions.md" |
| 4 | Vague approvals are rejected above low risk; decision strings are exact and upper case. | A01-A04 fixtures in `hooks/_test/run.sh` |
| 5 | The agent cannot switch its own guardrails off: hook scripts, hook config and the install record are protected. | W05, C03 fixtures |
| 6 | Source writes on tier 2-3 need a passed `PLAN_CHECK.md`, no open gate, and an execution-family stage. | W02, W03, W06 fixtures |
| 7 | Every approved artifact is hashed at approval; a later change is detected. | X02 fixture |
| 8 | Evidence is generated, never authored. A summary is never proof. Verification fails closed: an error computing coverage is a FAIL, never a pass. | W08, C05, H05 (seal) fixtures; X03 fixture; `tests/aidlc-phase2.test.js` "fails closed" |
| 9 | Tier 1 adds at most one log line per gate. Casual approvals are normalised, not rejected. | "low risk casual normalised" fixture |
| 10 | Hooks are inert until a project runs `setup/init-track.sh`; installing sdlc_central never blocks a project that has not adopted AIDLC. | "inert without a track root" fixture |
| 11 | Every hook runs on bash 3.2, needs only `jq` and `shasum`, and finishes inside 200 ms. | bash 3.2 test; timing check in `hooks/_test/run.sh` |
| 12 | Every block code a hook emits is declared in its `hook.yaml`, and every hook carries a `design_ref`. | "declares every block code it emits" test |
| 13 | Installing, updating and uninstalling never drops a user's own agent settings or hooks; uninstall never deletes the track root. | install wiring tests |
| 15 | A pass needs fresh evidence: a run whose touched files changed since, whose log is missing or altered, or whose suite re-run disagrees, does not count. | `tests/aidlc-phase2.test.js` stale, missing-log, altered-log and re-execution tests |
| 14 | Non-goals stay non-goals: no hosted control plane, no database, no compiled engine, no new lifecycle vocabulary. | Review; any change here needs a tech-lead decision first |

## Decisions still needed from a human

These come from the PRD's "decisions needed before Phase 1 starts". Phase 1 was built on the
assumptions shown; record the real decision with the approval guard once the track root is
initialised.

| Decision | Assumed in phase 1 |
| --- | --- |
| Closed decision vocabulary, with casual approvals allowed at low risk only | Yes, as designed |
| Claude Code is the only enforcing agent in phase 1; others advisory | Yes |
| Hub is a separate repository (not a monorepo directory) | Not yet built (phase 4) |
| Price Elasticity installs phase 1 before its sprint 3 release decision | Not yet scheduled |
