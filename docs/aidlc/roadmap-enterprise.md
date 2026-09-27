# Atticus enterprise roadmap

Status: approved 2026-09-26. Progress is tracked per milestone at the end of this file.

## Context

A Principal-engineer review of Atticus (branch `aidlc_framework`) found it a strong reference design, but not an enterprise control framework. Four problems are structural:

1. **Trust lives on the developer's laptop.**
   - Hooks enforce only on Claude Code.
   - Seals are unkeyed sha256 hashes that anyone can recompute.
   - Decider identity defaults to `git user.name`.
   - CI re-runs no tests.
2. **One global `CURRENT_PHASE` per repo.**
   - Shared append-only files (`lineage.md`, `human-decisions.md` with max+1 ids, `risks.md`, `gate-history.json`) conflict across parallel branches.
3. **A second system of record.**
   - `.track/` duplicates Jira/ADO, PR approvals and CI.
   - DORA figures come from a markdown "released" event.
4. **Ceremony invites rubber-stamping.**
   - The Bench rewards short gate waits.

Also weak:
- Test first can be gamed locally.
- The regex command guard is easy to bypass.
- The runner is a prompt.
- The core is 6,000 lines of bash, tested on macOS only.
- 12 tests fail.
- About 1,000 of 1,177 tests are structural.
- Scope is sprawling: 71 skills, 10 adapters.

The user asked to incorporate all eight recommendations. Decisions already taken:

| Decision | Choice |
| --- | --- |
| Core language | **Go** |
| Trackers | **Jira + Azure DevOps Boards** |
| Git hosts | **GitHub, GitLab and Azure Repos** |
| Non-core parts | **Frozen in place**: experimental, out of the default install |

**Outcome:**
- CI on the git host is the authority, with signed evidence.
- Approvals are PR/MR reviews by authenticated owners.
- Units are per branch with a conflict-free event ledger.
- Ceremony scales with measured risk.
- One Go binary, cross-platform, with behavioural tests and zero failures.
- A narrowed supported surface.
- A 6-week pilot with kill criteria.

---

## Target architecture

### Go module (`cmd/atticus`, Go 1.23, CGO off)

| Package | What it does |
| --- | --- |
| `cmd/atticus` | cobra commands: `start, status, context, next, hook, gate, verify, redgreen, risk, attest, release, deploy, migrate, ledger, dispute, metrics, init, setup, update, doctor` |
| `internal/track, ids, unit, config` | Layout detection, ULID and tracker-key ids, `unit.yaml` v2, gate-config v2 |
| `internal/ledger` | One immutable JSON file per event; sort by `(at, id)`; append-only check |
| `internal/state` | Folds events into unit state, replacing the `## AIDLC_RESUME` block; binds branch to unit |
| `internal/views` | Renders legacy `state.md`, `lineage.md`, `human-decisions.md`, `risks.md`, `gate-history.json` for compatibility |
| `internal/evidence, verify, scorecard, trace, gate` | Ports of the bash tools, using them as behaviour specs |
| `internal/risk` | Diff-based scorer and sampling |
| `internal/redgreen` | Adapters for node:test, jest, vitest, pytest, go test, JUnit (maven/gradle), plus a TASKS `Verify:` fallback |
| `internal/mutation` | Sampled, time-boxed runs of Stryker, mutmut, gremlins and PIT |
| `internal/attest` | Sigstore keyless signing (GitHub, GitLab) and cosign with an Azure Key Vault key (Azure) |
| `internal/providers/{github,gitlab,azure}` | PR/MR, approvals and votes, owners, checks and statuses, review timeline, deploy events |
| `internal/trackers/{jira,ado}` | Tracker interface; `internal/changerecord` is an interface with a `none` implementation (ServiceNow slot, not built) |
| `internal/hooks` | Claude Code hook protocol and the W/C/F rule registry |
| `internal/guard/cmdparse` | Shell parsing with `mvdan.cc/sh/v3` |
| `internal/migrate` | v1 ↔ v2 migration |
| `internal/metrics` | DORA, pilot metrics, read time |

- **Releases:** goreleaser builds darwin, linux and windows for amd64 and arm64, with cosign-signed checksums and SLSA provenance.
- **Bootstrap:** `get-atticus.sh` downloads the signed binary and verifies it.
- **Retired:** `package/` (npm) and `setup/install.sh`.

### `.track` layout v2 (conflict-free)

```
.track/layout-version                         "2"
.track/units/<UNIT_ID>/unit.yaml              UNIT_ID = PAY-142 | ADO-4567 | u-<ULID>; no global NN
.track/units/<UNIT_ID>/{SPEC,PLAN,PLAN_CHECK,TASKS,REVIEW}.md
.track/events/<UNIT_ID>/<ULID>.<type>.json    one immutable file per event
.track/events/_project/<ULID>.<type>.json
.track/legacy/                                v1 files after migration (read-only)
.track/views/                                 generated, gitignored legacy renderings
```

**Branch binding.** The current unit comes from the branch name (`<type>/<KEY>-slug`) or from `git config branch.<b>.atticus-unit`. Nothing global is committed. `start` refuses only if the same unit is already bound to another branch.

**Event schema v1:**
- Fields: `{v, id(ULID), unit, type, at, actor{id, login, kind, authenticated}, source{host, repo, branch, commit, pr, run_id}, subject{path, sha256}, data, attestation{predicate_type, ref}}`.
- Types are a closed set:
  - `unit.started`, `stage.entered`, `artifact.accepted`, `evidence.recorded`
  - `gate.evaluated`, `decision.recorded`
  - `guardrail.fired`, `guardrail.disputed`
  - `risk.raised`, `risk.closed`
  - `sample.selected`, `sample.reviewed`
  - `deploy.recorded`, `migration.imported`, `cli.invoked`

**Ledger of record:**
- Branch events are committed in the PR.
- Events CI observes (decisions, gate evaluations, samples, deploys) are written after merge to a protected orphan branch, `atticus/ledger`. Only the bot pushes there.
- There is no hash chain, since a chain would bring conflicts back. Integrity comes from three checks instead:
  - `ledger-lint` fails if a PR modifies or deletes an existing event file.
  - Every event must pass schema validation.
  - The tree of `events/` is attested after merge.

**No committed trusted reports.** CI produces VERIFICATION and SCORECARD as attested predicates and renders them in the check summary. Local runs write previews labelled `trust: local`, which gates never accept.

**Ids:**

| Item | Id |
| --- | --- |
| Unit | Tracker key, else `u-<ULID>` |
| Decision | `HD-<ULID>` (8-character display alias) |
| Risk | `RISK-<UNIT>-<ULID8>` |

Migrated units keep `legacy_id`.

### Hooks and the local role

- `.claude/settings.json` calls `atticus hook <event>` directly.
- During the transition, each bash `wrap.sh` becomes a shim: use the Go binary when `ATTICUS_ENGINE=go` (the default) and it is present, otherwise the old bash.
- **Latency:** p95 must stay under 50 ms, and CI fails above that.
- **Blocking locally is kept for:**
  - destructive commands
  - pushes to protected refs
  - edits to existing event files
  - source writes before the plan gate
- Everything else warns.
- **Plan gate locally:** PLAN.md must be on the default branch at an attested gate commit. The lookup is cached in `.git/atticus/cache`. When offline the hook warns, and CI enforces the rule anyway.
- **Command guard via the shell parser.** It walks every call, including inside `;`, `&&`, pipes, subshells and `$( )`. It closes these bypass families:
  - `rm` variants: `\rm`, `command rm`, `env rm`, `-f -r`, `--recursive`, `find -delete`
  - git options and refspecs: `git -C/-c`, `HEAD:main`, `+main`, `:main`, `--mirror`, `--tags`, `--force*`
  - publishing: `docker push`, `npm publish`, `twine upload`
  - `bash -c`, `sh -c` and `eval`, which are parsed again recursively
  - `python -c` and `node -e`: blocked when they name a protected path, otherwise a warning
  - The parser gets fuzz tests.

---

## CI on each host: the enforcement point (recommendations 1 and 5)

Every host runs the same jobs:

| Job | Trigger | Purpose |
| --- | --- | --- |
| `ledger-lint` | PR | Schema, append-only check, unit.yaml |
| `risk` | PR | Score the diff; post status and breakdown |
| `gate` | PR and review events | Required approvers by risk; stale-approval and self-approval checks; read-time capture |
| `redgreen` | PR with code changes | New tests fail at merge-base and pass at head |
| `verify` | PR | TASKS `Verify:` commands, traceability, consistency, scorecard; produces the verification predicate |
| `attest` | PR head and merge commit | Sign the gate, verification and redgreen predicates, bound to the commit SHA |
| `ledger-record` | After merge | Write decision, gate and sample events to `atticus/ledger` |
| `release-check` | Deploy stage | Verify attestations for every unit in the range, the environment approval and the change-record provider |
| `deploy-record` | End of deploy | Emit `atticus.dev/deploy/v1` |

### GitHub
- **Workflow:** `adapters/_shared/ci/github/atticus.yml`.
- **Permissions:** `contents: read`, `pull-requests: read`, `checks: write`, `statuses: write`, `id-token: write`, `attestations: write`.
- **Actions:** pinned by SHA, kept current by Dependabot.
- **Attestation:** `actions/attest` with custom predicates `atticus.dev/{gate,verification,redgreen}/v1`, signed keyless through Sigstore. `release check` verifies them with sigstore-go against the repo and workflow identity.
- **Approvals:** from `pull_request_review` with state approved. The job keys on the numeric user id.
- **CODEOWNERS:**
  - `SPEC.md` → product owners
  - `PLAN.md` → architects
  - security paths → appsec
- **Ruleset on the default branch:**
  - code-owner review required
  - stale reviews dismissed
  - approval of the last push required
  - required checks: `atticus/{gate,verify,redgreen,ledger-lint}`
  - merge queue on; force-push and delete blocked
- **Tag ruleset:** only the release team may create `v*` tags.
- **Release:** the `production` environment has required reviewers plus `atticus release check`.
- **Retired:** `aidlc-decision.yml` (workflow_dispatch with asserted identity).

### GitLab
- **Template:** `include:` of `atticus.gitlab-ci.yml`, using merge-request pipelines and merge trains.
- **Approvals:** approval rules plus CODEOWNERS sections.
- **MR settings:**
  - prevent author and committer approval
  - reset approvals on push
  - re-authentication required to approve
  - pipelines must succeed
- **API access:** a project access token with `read_api` scope, stored as a masked variable.
- **Attestation:** `id_tokens` with a sigstore audience, then keyless signing. The bundle is stored in the generic package registry, keyed by SHA.
- **Release:** protected environments with deployment approvals, plus protected tags.

### Azure Repos and Pipelines
- **Template:** `extends` template. Branch policies:
  - minimum reviewers
  - the most recent pusher may not approve
  - votes reset on push
  - build validation
  - a status policy on `atticus/gate` (posted through the PR Status API)
- **Owners:** required reviewers by path filter, since Azure has no CODEOWNERS.
- **Identity:** votes are read from `pullRequests/{id}/reviewers` (vote 10 means approved), keyed by the Entra object id.
- **Attestation:** cosign with a non-exportable Key Vault key (`azurekms://`) through a workload-identity service connection. The verifier pins the public key.
- **Release:** environments with Approvals & Checks, the "Required template" check, and `release-check`.

`authenticated_identity_required` flips to true once all three providers are live.

---

## Red then green in CI (recommendation 5)

1. `base = merge-base(target, head)`. Each language adapter's `ChangedTests(diff)` picks the new or changed tests:
   - **node:test, jest, vitest:** `*.{test,spec}.*` files. Added `it(` or `test(` lines select single tests; otherwise the whole file runs.
   - **pytest:** `def test_` node ids.
   - **Go:** `func TestX` with `-run`.
   - **Java:** `@Test` methods, run with `-Dtest` or `--tests`.
   - **Fallback:** TASKS `Verify:` commands tagged `red:`.
2. **At head:** the tests must pass. They run twice, and differing results mark the test `flaky`, which does not count as proof.
3. **At base:** a worktree at base gets only the head's test files and test-support directories. The tests must fail.
   - An assertion or missing-symbol failure is `red`.
   - A package that fails to compile is `red:compile`, with lower confidence.
   - A test that passes at base is `non-proving`.
4. **Policy:**
   - Medium or high risk code changes need at least one proving test, or a signed waiver decision.
   - Low risk is report-only.
   - The predicate records `{base_sha, head_sha, runner, run_id, adapter, tests[]}`.
5. **Mutation testing:**
   - Only changed lines, capped at 10 minutes.
   - Sampled 5% for low risk, 20% for medium, 100% for high.
   - Reported only during the pilot. Afterwards high risk needs 60%.

`aidlc-evidence.sh --red` and the local rerun in `aidlc-verify.sh` become local previews marked `trust: local`.

---

## Risk-proportional ceremony (recommendation 4)

**Score, 0 to 100.** Inputs come from the merge-base diff. For a spec or plan PR, they come from the files PLAN.md declares.

| Signal | Points |
| --- | --- |
| Each sensitive path class: authn/z, crypto, secrets, payments/PII, DB migrations, infra, CI workflows, CODEOWNERS, `.track/config` | +20 each, max 40 |
| Contract touched: OpenAPI, proto, GraphQL, public API, event schemas | +20, or +40 if breaking |
| Distinct owner groups touched | 2 groups +10; 3 or more +20 |
| Churn | 0, 5, 10 or 20 by lines changed; +10 if more than 20 files |
| Dependency manifest changed | +10; +15 for a new direct dependency |
| Hotspot: reverted or incident-linked in the last 90 days | +10 |
| Code change with no proving test | +15 |

- **Bands:** low is below 25, medium 25–54, high 55 or more.
- **Floors:**
  - Any sensitive path means at least medium.
  - Sensitive plus a contract change means high.
  - The `unit.yaml` tier is a floor.
- **Config:** weights are versioned in config, and the breakdown is posted on the PR.

**What each band requires:**

| Band | Spec/plan gate | Code review | Mutation sample | Release |
| --- | --- | --- | --- | --- |
| Low | Auto-approved, with evidence (`gate.evaluated auto:true`) | 1 reviewer | 5% | Normal |
| Medium | Product owner + architect code owners | 1 | 20% | Normal |
| High | Product owner + architect + appsec | 2 | 100% | Change-record provider called |

The `gate` check enforces the approvers that vary by risk, because rulesets cannot vary by risk.

**Sampling, low band only:**
- A unit is selected when `hash(unit_id ‖ weekly_salt) mod 100 < rate`. The rate starts at 10%, with at least 1 per squad per week.
- A selected unit gets a post-merge review task in Jira or ADO for a random code owner. The outcome is recorded as `sample.reviewed`.
- If defects exceed 5% over 4 weeks, Atticus proposes tightening the band. It does not apply the change itself.

**Read time instead of approval speed:**
- `read_time_s` runs from first engagement to approval. It is recorded with comment and thread counts.
- The expected read time is words ÷ 250 per minute.
- A rubber-stamp flag is raised at less than 0.2 × expected with zero comments. It is a metric, not a block.
- The Bench's gate-wait share KPI and gate-wait column are removed (`console/bench.js`).

---

## Integrations (recommendation 3)

- **Tracker interface:** `Resolve`, `Link`, `Transition`, `Comment`.
  - **Jira:** Cloud v3 with an API token, Data Center v2 with a PAT. Remote links go to the PR or MR, and a configurable transition map moves the issue, for example `approve-plan.passed → Ready for Dev`.
  - **Azure Boards:** work item REST, `ArtifactLink`, and the `AB#` convention.
  - **Where calls happen:** writes happen only in CI. Locally, the tracker is only read by `atticus start` to fetch the title.
- **Unit id** is the issue key. `atticus start PAY-142` creates the branch, `unit.yaml` and a `unit.started` event.
- **`ChangeRecordProvider`:** `Open`, `Status`, `Close`. Only a `none` implementation ships, with a contract test suite ready for ServiceNow later.
- **DORA from deploys:** `atticus deploy record --service --env --status`.
  - The event is attested and written to `atticus/ledger`.
  - Lead time runs from the PR's first commit to its successful deploy.
  - Change failure counts a failure, a rollback, or an incident linked within 7 days.

---

## Narrowed scope (recommendation 7)

**Supported:**
- the Go `atticus` CLI
- Claude Code hooks (enforcing)
- a generic `AGENTS.md` adapter (advisory; CI enforces)
- the three CI templates
- about 8 skills: `atticus, spec-gen, plan-gen, task-gen, task-implementer, review, gate-briefing, decision-log`

**Frozen in place** (marked experimental, excluded from the default install and the supported test matrix):
- the other 63 skills
- the other 8 adapters
- the hub and contracts
- the console and Bench
- the knowledge index and wiki lint

The install matrix drops from 8 roles × 10 agents to 3 roles × 2 agents.

---

## Migration and deprecating bash

- **`atticus migrate --to v2 [--dry-run]`:**
  - `git mv phases/NN-slug` to `units/<key or legacy id>`.
  - Converts lineage, decisions, guardrail log, risks and gate history into events. Each ULID's time comes from the line's timestamp and its entropy from the line's hash, so the migration is idempotent.
  - Imported decisions are marked `authenticated:false`.
  - The originals move to `.track/legacy/`, and it all lands in one commit.
- **`--to v1`:** re-renders the legacy files through the views code.
- **Round trip:** v1 → v2 → v1 must be byte-equal after a documented normalisation. This is tested on every fixture and on the repo's own `.track`.
- **Compatibility period:**
  - Bash readers read `views/`.
  - Bash writers detect v2 and point to `atticus <cmd>`.
- **Schedule:**
  - M2: Go becomes the default, with `ATTICUS_ENGINE=bash` as a fallback.
  - After the pilot: bash leaves the default install.
  - One release later: bash is deleted.

---

## Milestones

Estimated at about 40 engineer-weeks, or about 14 weeks with 3 engineers, before a 6-week pilot.

| # | Milestone | Depends on | Effort | Exit criteria |
| --- | --- | --- | --- | --- |
| M0 | Stabilise and freeze | none | 2 ew | Fix the 12 failures: generate SKILL.md for the 10 skills or relax the legacy check; add them to `setup/install-all.sh`; make `tests/skill-manifest.test.js:32` count from the registry. Move frozen parts behind experimental flags. SHA-pin actions and add `permissions:` to the current CI. Remove the gate-wait KPI. Write hook behaviour specs. Kill criteria signed off. **`node --test` has 0 failures.** |
| M1 | Go core: ledger, state, ids, views, migrate | M0 | 6 ew | testscript ports of phase tests 1–5 pass. Round-trip migration passes. A two-worktree parallel-branch scenario merges with **zero conflicts**. CI matrix passes on ubuntu, macos and windows. |
| M2 | Hooks in Go with cmdparse | M1 | 4 ew | All 94 fixtures ported. A differential harness compares bash and Go, and every difference is documented. Bypass fixtures added. Fuzz tests. p95 under 50 ms, enforced. |
| M3 | GitHub CI trust: verify, scorecard, trace, redgreen (node, pytest, Go), attest, gate from reviews | M1, in parallel with M2 | 7 ew | In a sandbox org: a PR without a proving test is blocked; a forged local VERIFICATION is ignored; a tampered event fails lint; a commit without attestations fails `release check`; self-approval is rejected. |
| M4 | Risk model, sampling, read time, Jira + ADO | M3 | 5 ew | About 40 golden diffs score as expected. Sampling is deterministic. Tracker contract tests against recorded HTTP, plus one live sandbox run each. |
| M5 | GitLab + Azure providers and attestation | M3 | 6 ew | The M3 trust scenarios pass on both hosts. Key Vault signs and verifies. Approval rules are confirmed through the APIs. |
| M6 | Java adapter, mutation sampling, deploy events, DORA, release gate | M3, M4 | 4 ew | Seeded proving, non-proving and flaky tests are classified correctly in each language. DORA matches a hand-computed fixture. |
| M7 | Pilot, 6 weeks | M4 (+M5 for non-GitHub squads) | 3 ew support | See Pilot. |
| M8 | Remove bash; flip `authenticated_identity_required` | Pilot says "continue" | 2 ew | The default install has no `.sh` hooks. Docs updated. |

- **Critical path:** M0 → M1 → M3 → M4 → M7.
- **Staffing, 3 engineers:**
  - E1: ledger, state, migration, trackers.
  - E2: CI, providers, attestation.
  - E3: hooks, cmdparse, redgreen, risk.
- **Test target:** at least 70% behavioural cases. The skill-manifest checks collapse into one table-driven test.

---

## Pilot (recommendation 8)

- **Squads:** 2, one of them on GitLab or Azure.
- **Timeline:**
  - Weeks −2 to 0: capture the baseline through host and tracker APIs, and run CI in shadow mode.
  - Weeks 1–2: advisory.
  - Weeks 3–6: enforcing.
  - Week 3: mid-point review. Stop early if false blocks exceed 15%.

**Instrumentation:**

| Measure | How it's collected |
| --- | --- |
| Overhead minutes per unit | Opt-in `cli.invoked` durations; CI job time; pushes after a gate failure; a weekly one-question estimate |
| False blocks | `atticus dispute <event-id> "<reason>"`, triaged weekly. An upheld dispute counts as a false block. Admin bypasses are counted from audit logs. |
| Read time and rubber-stamp rate | Per gate and per risk band |
| Sentiment | A weekly three-question pulse (helped quality, slowed me, would keep) plus exit interviews |
| Outcomes | Proving-test rate, escaped defects on auto-approved units, DORA against the baseline |

**Kill criteria**, assessed at week 6. Any one of these means stop or rework:

1. Median overhead above 30 minutes per medium unit, or above 10 minutes per low unit.
2. False blocks above 5% of blocks, or above 1 per developer per week.
3. p50 lead time more than 20% worse than baseline, with no measurable defect reduction.
4. "Would keep" below 3.0 out of 5, or fewer than 50% would continue.
5. Rubber-stamp rate above 50% on medium and high gates.
6. More than 3 bypasses of required checks per squad per week.

**Continue** requires all six to pass, plus a proving-test rate of at least 70% on code units.

---

## Handoff roleplay (GitHub; Jira PAY-142, "Idempotency keys on refund API")

1. **Developer:**
   - Runs `atticus start PAY-142`.
   - Gets the title from Jira, the branch `feat/PAY-142-refund-idempotency`, `units/PAY-142/unit.yaml` and a `unit.started` event.
   - The agent writes SPEC and PLAN with an `atticus context` digest of about 300 tokens, and they go into PR #881.
   - A teammate starts PAY-150 on another branch at the same time. There is no lock and no conflict.
2. **CI on #881:**
   - `risk` scores the declared paths: payments is sensitive (+20), the OpenAPI contract (+20), and owner groups (+10), for 50. The sensitive-plus-contract floor makes it **high**.
   - `gate` requires the product owner, an architect and appsec.
   - Jira moves to "In Design Review" with a link to the PR.
3. **Reviewers:**
   - The product owner reads for 11 minutes, leaves 3 comments and approves.
   - The architect requests changes. The new push dismisses the approvals, and both re-approve.
   - AppSec approves.
   - The gate passes, the merge commit gets a `gate/v1` attestation, and `ledger-record` writes 3 authenticated `decision.recorded` events with their read times.
   - Jira moves to "Ready for Dev".
4. **Developer, PR #894:**
   - The hook sees PLAN on main with an attested gate, so source writes are allowed.
   - The agent tries `git -C . push origin HEAD:main`. The parser blocks it and records `guardrail.fired`.
   - A new test is added: `refund.idempotency.test.ts`.
5. **CI on #894:**
   - `redgreen`: at base the test fails (expected 409, got 201); at head it passes twice. It is proving.
   - Mutation score is 71%.
   - `verify` passes, and 2 reviewers approve.
   - `verification/v1` and `redgreen/v1` are attested.
6. **Release manager:**
   - Tags `v2.14.0`, which only the release team can do.
   - Approves the `production` environment.
   - `atticus release check` verifies every attestation in the range. The `none` change-record provider logs a skip.
   - `atticus deploy record` feeds DORA.
7. **Counter-case, PAY-150** (a docs string fix):
   - Risk 8, low band.
   - The spec/plan gate is auto-approved with evidence. The unit is not in the sample. It needs 1 code review.
   - Had PAY-142's 1,800-word spec been approved in 40 seconds with no comments, it would show a rubber-stamp flag, not a block.

## Token budget and cost reduction

**Governance overhead per medium unit:**
- **Today:** about 100–140k input tokens. The runner, contract and personas are re-read across about 40 turns, state and lineage are read, and an LLM briefing runs at each gate.
- **Target:** at most 25k.
  - spec-gen: about 12k in, 3k out.
  - plan-gen: about 18k in, 5k out.
  - About 10 digests of roughly 0.3k each.
  - An 8k briefing, for high risk only.
  - CI enforcement, verification, risk scoring and summaries cost **0 tokens**.

**Tactics:**
1. Move routing into `atticus next` and `atticus context`. The runner prompt shrinks to a 300-token explainer.
2. Cache one stable preamble covering the contract and persona.
3. The digest replaces raw `.track` reads.
4. Code renders the PR check summaries. The LLM briefing is opt-in and for high risk only.
5. Limit repo context to the files PLAN declares.
6. Use a small model for summaries and linting, and a large one for spec and plan authoring.
7. CI runs only the changed tests (twice at head, once at base), with mutation testing sampled and time-boxed.

---

## Critical existing files

**Behaviour to port, with golden tests:**
- `hooks/_lib/track-parse.sh`: `aidlc_load_state` (:96), tier resolution (:113-119), `aidlc_lineage`, `aidlc_log_guardrail`
- `hooks/_test/run.sh`: 94 fixtures, the hook-parity spec
- `tests/aidlc-phase1..5.test.js`, `tests/aidlc-bench.test.js`, `tests/atticus-cli.test.js`: port to testscript
- `hooks/_bin/aidlc-evidence.sh` (schema :160-172, masking :94-98, `--red` :181), `hooks/_bin/aidlc-verify.sh` (coverage :118-148, test-first :153-175, rerun :177-209, seal :255)
- `hooks/_bin/aidlc-scorecard.sh` (D1-D6), `hooks/aidlc-traceability-check/`, `hooks/aidlc-artifact-consistency-check/` (X01-X05)
- `hooks/aidlc-human-approval-guard/aidlc-human-approval-guard.sh`: gate binding :28-46, HD splice :176-262, risk ids :218-223, A05 :159-164, A06 :165-173

**To replace or retire:**
- `adapters/_shared/ci/aidlc-checks.yml`, `adapters/_shared/ci/aidlc-decision.yml`, `setup/install-ci.sh`: replaced by the three host templates
- `hooks/aidlc-pre-command-guard/aidlc-pre-command-guard.sh`: its regex list is replaced by cmdparse
- `hooks/aidlc-final-verification/aidlc-final-verification.sh:26`: its local release regex is replaced by `release-check`
- `hooks/_bin/aidlc-start.sh`, `bin/atticus`, `get-atticus.sh`: replaced by the Go CLI and signed-release bootstrap
- `package/`, `setup/install.sh`: retired

**Other edits:**
- `pipelines/_engine/PIPELINE-RUNNER.md`, `pipelines/_engine/AIDLC-CONTRACT.md`, `agents/aidlc-*/prompt.md`, `skills/atticus/prompt.md`: prompts shrink to explainers that call `atticus context` and `atticus next`
- `config/gate-config.json`: v2 risk weights, bands, sampling, providers; `authenticated_identity_required` flip in M8
- `console/bench.js`: remove the gate-wait KPI (:172, :215, :226, :245), then freeze

## Verification (end to end)

- **Every milestone:**
  - `go test ./...` passes, including testscript ports.
  - The Go/bash differential harness shows only documented differences.
  - `node --test tests/*.test.js` has 0 failures while the node tests exist.
  - The OS matrix passes on ubuntu, macos and windows.
  - Hook p95 is under 50 ms.
- **Concurrency:** a scripted two-worktree scenario. Both branches start units, record events and get decisions, then merge in either order with zero conflicts. The folded state matches what is expected.
- **Trust, per host (sandbox org or project):** each of these must be rejected:
  - a forged local VERIFICATION
  - an edited event file
  - self-approval
  - a PR without a proving test at medium risk
  - a release of a commit without attestations
  - `release check` verifies the signatures offline against the pinned identity or key.
- **Migration:** a v1 → v2 → v1 round trip on fixtures and on this repo's `.track`. Rehearse the dogfood migration in a worktree.
- **Risk and sampling:** golden diffs, a determinism test, and a live PR showing the posted breakdown.
- **Trackers:** recorded-HTTP contract tests, plus one live sandbox issue each for Jira and ADO.
- **Pilot readiness:** the instrumentation dashboard shows the baseline and shadow-mode data for both squads before enforcement is switched on.

---

## Progress

| Milestone | Status |
| --- | --- |
| M0 Stabilise and freeze | Done in code (2026-09-26): 0 failing tests; `registry/support.yaml` and `--experimental`; CI least-privilege and SHA-pinned; gate-wait KPI removed; hook behaviour spec `docs/aidlc/spec/hook-behaviour.md`. pilot kill criteria signed off by the sponsor on 2026-09-27 (`docs/aidlc/pilot.md`) |
| M1 Go core | Core delivered 2026-09-27: `atticus-core` with ids, track, unit, ledger (+ lint), state fold and branch binding, views, v1↔v2 migration; two-worktree zero-conflict test in both merge orders; byte-exact round trip on fixtures and this repo's `.track`; CI workflow for ubuntu, macOS and Windows. **Remaining:** testscript ports of phase tests 1–5 (they target v1 bash tools until M2/M3); first green run of the Windows CI job |
| M2 to M8 | Not started |
