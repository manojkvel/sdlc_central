# Design decisions

D-NNN entries written by the decision-log skill. DEC-NNN is accepted as an alias.
Gate approvals are not recorded here; they live in human-decisions.md.

### D-001: `.track/` is the AIDLC root directory
- **Source:** user instruction in chat, 2026-09-24: "instead of .planning lets rename it as .track"
- **Decision:** the canonical root is `.track/`, configurable through `track_root`; the reference implementation's `.planning/` is supported by setting `track_root: .planning` or importing with `migrate-specs.sh --from .planning`.
- **Status:** ACTIVE

### D-002: Implementation starts on branch `aidlc_framework` with phase 1 (control and audit rails)
- **Source:** user instruction in chat, 2026-09-25: "lets create a new branch aidlc_framework and start the implementation"
- **Decision:** phase 1 delivers hooks, schemas, gate config, installer wiring, init and migration scripts, runner changes and the plan-check skill. `plan-check` moved forward from phase 2 because the pre-write guard depends on it.
- **Status:** ACTIVE
