# Track layout v2: the conflict-free ledger (roadmap M1)

v1 kept one global resume block (`state.md`) and appended every record to shared files
(`lineage.md`, `human-decisions.md`, `guardrail-log.md`, `risks.md`, `gate-history.json`), numbered with
max+1 counters. Two branches working at once therefore conflicted on every merge, and a repository
could have only one active unit. v2 removes both limits.

## Layout

```
.track/layout-version                         "2"
.track/units/<UNIT>/unit.yaml                 plus SPEC, PLAN, PLAN_CHECK, TASKS, REVIEW …
.track/events/<UNIT>/<ULID>.<type>.json       one immutable file per event
.track/events/_project/<ULID>.<type>.json     events that belong to no unit
.track/legacy/                                v1 files after a migration (read-only)
.track/views/                                 generated v1-shaped files for old readers (gitignored)
```

- **Unit ids** are tracker keys: `PAY-142` (Jira), `ADO-4567` (Azure Boards; `AB#4567` is accepted),
  `u-<ULID>` for work with no issue, `legacy-NN-slug` for migrated v1 phases.
- **The current unit comes from the branch.** `feat/PAY-142-refund` works on `PAY-142`. Any other branch
  name is bound with `git config branch.<b>.atticus-unit <unit>` (local, never committed). Nothing global
  is committed, so any number of units can be in flight.
- **State is a fold.** A unit's stage, open gate, decisions and risks are computed from its own events,
  sorted by time then ULID. No reader depends on file or line order.

## Event schema (v1)

```json
{"v":1,"id":"01J9X…","unit":"PAY-142","type":"decision.recorded","at":"2026-10-02T14:03:11Z",
 "actor":{"id":"github:1234567","login":"mlee","kind":"human","authenticated":true},
 "source":{"host":"github","repo":"org/pay","branch":"feat/PAY-142-plan","commit":"<sha>","pr":"881","run_id":"…"},
 "subject":{"path":".track/units/PAY-142/PLAN.md","sha256":"…"},
 "data":{"gate":"approve-plan","verdict":"approved"},
 "attestation":{"predicate_type":"https://atticus.dev/gate/v1","ref":"sha256:…"}}
```

Types are a closed set: `unit.started`, `stage.entered`, `artifact.accepted`, `evidence.recorded`,
`gate.evaluated`, `decision.recorded`, `guardrail.fired`, `guardrail.disputed`, `risk.raised`,
`risk.closed`, `sample.selected`, `sample.reviewed`, `deploy.recorded`, `migration.imported`,
`cli.invoked`. `authenticated` is true only when the git host or CI vouched for the identity (M3 onward).

## Integrity

- Events are written with exclusive create and never overwritten.
- `atticus-core ledger lint --base <merge-base> --head HEAD` fails when a change modifies, deletes or
  renames an existing event file (L101), adds an invalid event (L102) or puts one in the wrong place
  (L103). CI runs it on every pull request from M3.
- There is deliberately no hash chain across files: a chain would bring the merge conflicts back.
  Post-merge attestation of the events tree (M3) provides tamper evidence instead.

## Commands (`atticus-core`, also reachable through `atticus`)

| Command | What it does |
| --- | --- |
| `layout init` | Create a v2 track root |
| `start <ISSUE-KEY> [--name] [--tier] [--profile] [--branch] [--no-branch]` | Start a unit on its own branch |
| `status [--unit]` / `context [--unit]` | The unit's state, or a short digest for an agent |
| `ledger list / record / lint` | Read, append and check events |
| `migrate --to v2 [--dry-run] [--force]` / `--to v1` | Convert the layout; reversible and byte-exact for v1 content |
| `views` | Regenerate `views/state.md` and `views/lineage.md` |

## Migration

- `--to v2` moves `phases/NN-slug` to `units/legacy-NN-slug` (or the issue key), keeps each v1
  `unit.yaml` byte-for-byte under `legacy/unit-yaml/`, moves the shared ledgers to `legacy/` and converts
  every record into an event. Event ids are deterministic, so migrating twice writes identical files.
  Imported decisions are `authenticated: false`.
- `--to v1` restores the originals exactly. Units and events created after the migration become
  `phases/NN-<id>/` and appended lineage lines.
- Until M2 the bash hooks do not read v2, so `--to v2` needs `--force`, and on a v2 track every hook
  prints a warning that local enforcement is off.
