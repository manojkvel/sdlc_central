# Plan: Patch-driven spec evolution + Director-scale ops

> Sits on top of `three-new-skills-plan.md`. The three skills (traceability-gen, parallel-kanban, task-briefing-gen) handle the *initial* spec→build flow. This plan handles what happens **after** — mid-implementation discoveries, portfolio rollups, accountability loops — so the framework survives at 30+ dev scale.

> **Sanity-checked 2026-04-18** against the existing `spec-evolve`, `board-sync`, and `feedback-loop` prompts. Overlaps were collapsed into extensions of existing skills (primarily `spec-evolve`) rather than new parallel skills. Net: **4 new skills + 4 extended**, not 6 new.

---

## Context

Two things surfaced in the NutriKids workshop that the three-skills plan didn't fix:

1. **The evolution problem.** When a dev discovers mid-task that "Docker beats VM" (TASK-014), the current framework forces a full regen of `spec.md → plan.md → tasks.md`. Cost: ~36k tokens per mid-sprint discovery, destroys human annotations, re-flows untouched sections. Fine once. Painful when it happens 3× a sprint.
2. **The Director-scope problem.** The three-skills plan is a single-feature loop. Running 8–15 features concurrently surfaces gaps the per-feature view can't fill: no portfolio board, no source-of-truth integration (Jira/Linear), no way to prove ROI, no accountability signal on "did the PR actually ship what was briefed."

Both share a root cause: **artefacts are treated as opaque blobs, and the loop is plan→build→regen instead of plan→build→amend.**

## Goals

1. A mid-implementation discovery costs **≤20% of a full regen** and preserves human edits.
2. A Director sees one portfolio view instead of N feature folders.
3. Every skill invocation is measured; framework rollout is gated on pilot ROI, not vibes.
4. Accountability is mechanical: briefing freshness, scope-delta at PR, compliance AC = auto-gate.

## Design principles

1. **Artefacts are addressable.** Stable IDs (`AC-7`, `PHASE-3`, `TASK-014`) + content hash at section level.
2. **Decisions are deltas.** ADRs in `decision-log.md` are the unit of change — not rewrites of upstream docs.
3. **Staleness is a flag, not an action.** Downstream sections mark 🟠 on upstream change; humans resolve.
4. **Discoveries batch into an amendment gate.** Per-commit cascades are forbidden.
5. **Instrument the loop or don't ship it.** If we can't prove ROI in 2 sprints, it's cut.
6. **Hashes are content-normalized.** Section hashes are computed on canonical form (stripped trailing whitespace, collapsed blank lines, normalized line endings). Reformatting ≠ staleness.

---

## Part A — Patch-driven evolution

### A1. Section addressing (foundation)

Every spec / plan / tasks file gets a front-matter `sections:` index:

```yaml
---
version: 1.3
sections:
  AC-7:      { kind: functional,  lines: 42-48,  hash: sha-abc123, updated: 2026-04-18 }
  AC-8:      { kind: compliance,  lines: 49-55,  hash: sha-def456, updated: 2026-04-17 }
  PHASE-3:   { lines: 112-140, hash: sha-789xyz }
  TASK-014:  { lines: 201-215, hash: sha-ghi, deps: [TASK-002], refs: [AC-8, PHASE-3] }
---
```

Enforced/maintained by `spec-gen`, `plan-gen`, `task-gen` (modified — see Files to modify). Downstream citations change from "§5 L42-48" to `spec.md#AC-7@abc123`.

### A2. Extend `spec-evolve` with section-level patching

**Why extend, not create new:** `spec-evolve` already versions specs (`spec.v{N}.md`), classifies blast radius (`NONE/UPDATE/REGEN/DELTA/REWORK`), has `resolve` mode for minimal edits, emits `reprocess-manifest.json`, and has dry-run. The only gap is that every amendment produces a full `spec.v{N}.md` file instead of touching addressable sections. Collapsing this here avoids two skills doing 70% the same thing.

**Extensions to `spec-evolve`:**

1. **New mode: `--section <ID>`.** Operates on one addressed section. Reads only that section + dependents (via section index). Writes the section back in place, bumps its hash, flags downstream sections 🟠. Falls back to full `revise` mode only if `--full` is explicit.
2. **New blast-radius value: `SECTION_PATCH`.** Extends the existing enum (`NONE/UPDATE/REGEN/DELTA/REWORK`). Indicates "one or more sections patched; no whole-file regen; dependents flagged."
3. **New trigger source: `discovery-queue`.** Extends existing triggers (`spec-review/gate/stakeholder/implementation/planning`). When triggered this way, the ADR source is the DISC-NNN entry, not a report or gate-feedback file.
4. **Versioning still applies.** `spec.v{N}.md` still bumps — section-level patches produce a new version with only the touched sections showing hash changes in front-matter. Version history preserved.
5. **Reprocess manifest schema extension.** Existing `aggregate_action: {plan, tasks, board, impl}` gets a sibling `section_patches: [{section, old_hash, new_hash, dependents}]` so downstream skills can cheaply identify what to re-read.
6. **`quality-gate` validator extension.** Currently validates that `CLARIFICATION` blast-radius isn't `REGEN`. Analog needed: `SECTION_PATCH` can't silently touch sections outside the decision's `affects:` list.

**Does not:** invoke LLM for untouched sections. Pure tabular transform where possible.

**Cost:** ~6–8k per invocation (vs ~26k for the existing full-file revise flow, vs ~36k for cascaded regen).

### A3. New skill — `discovery-queue`

**Purpose:** Capture mid-implementation discoveries without triggering a cascade.

- Devs append to `discoveries.md` in the spec dir:
  ```
  DISC-012: Docker > VM for local dev runtime
  Found in: TASK-014  Raised by: Karan  2026-04-18
  Suggested impact: AC-8 deployment, PHASE-3 infra
  ```
- Skill lints format, dedupes, and cross-references against spec/plan sections.
- **Cost:** ~0.5k per discovery (append + lint, no LLM-heavy generation).
- **Roles:** `[developer, qa, architect]`.

### A4. New skill + pipeline — `amendment-gate` (batch wrapper)

**Purpose:** Human-approved batching layer over `spec-evolve`. Does not duplicate spec-evolve's logic — orchestrates it.

- Reads `discoveries.md`, cross-references each discovery against the section index to compute `affects:`.
- Presents each as:
  ```
  DISC-012: Docker > VM.  Affects: AC-8, PHASE-3, tasks [014, 017, 022].
  Patch preview (6k tokens, 3 sections):  [spec §8 -3/+8]  [plan §3 -4/+12]  [3 task cards +stale]
  [A]ccept / [R]eject / [D]efer:
  ```
- On Accept: writes ADR to `decision-log.md` (DEC-NNN), invokes `spec-evolve --section --trigger discovery-queue --source DISC-NNN` per accepted discovery, merges the resulting `reprocess-manifest.json` outputs into a single consolidated manifest, updates `amendment-log.md`, triggers `briefing-freshness-check` + `board-sync`.
- New pipeline file: `pipelines/developer/spec-amend.pipeline.yaml`.
- **Roles:** `[tech-lead, architect]`. Gate-protected (requires human approval).

### A5. Coexistence with existing implementation-ambiguity path

`/task-implementer` already routes ambiguities through `/auto-triage → /spec-evolve resolve`. That path stays. The boundary:

| Signal | Path | Why |
|---|---|---|
| Implementation-blocking ambiguity (dev stuck, answer unknown) | `auto-triage → spec-evolve resolve` | Unblock quickly; narrow targeted amendment |
| Non-blocking observation (dev has an opinion, not stuck) | `discoveries.md → amendment-gate → spec-evolve --section` | Batch for efficiency; preserve human judgment |

Discovery-queue is not a replacement — it's a second channel for a different signal class.

### A6. Backfill script for existing specs

Existing specs (e.g. `001-nutrition-app`) have no `sections:` front-matter. One-shot migration:

- New script `setup/backfill-section-index.sh <spec-dir>`:
  1. Parses AC/phase/task headings using existing prose conventions.
  2. Synthesizes IDs (`AC-N` from "AC-N: …" lines already present; `PHASE-N` from headings; `TASK-NNN` from tasks.md cards).
  3. Computes content-normalized hashes per section.
  4. Prepends front-matter without touching body content.
  5. Dry-run mode + diff output before write.
- Required for Phase 3 (rollout); pilot (Phase 1) uses new specs only so backfill isn't on the pilot critical path.

---

## Part B — Director-scale ops (review response)

### B1. Briefing freshness — `briefing-freshness-check` (new)

- `task-briefing-gen` stamps each briefing with the SHAs of sections it read:
  ```yaml
  pinned_sections:
    spec#AC-7: sha-abc123
    plan#PHASE-3: sha-789xyz
    tasks#TASK-014: sha-ghi
  ```
- `briefing-freshness-check` runs at (a) dev session start, (b) PR open. If any pinned SHA drifted: **blocks** with regenerate hint. No warn-only — stale briefings were the root friction.
- **Cost:** ~0.3k per check (hash compare, no LLM unless drift found).

### B2. Scope accountability — `briefing-delta` (new, PR-time)

- Reads: briefing (what was promised), PR diff (what was delivered).
- Writes: `briefing-delta-TASK-XXX.md` — AC coverage, scope creep, missed DoD items.
- **Gate:** warn-only for pilot; blocking after ROI proof (Part C).
- **Cost:** skipped entirely when briefing+PR SHAs match latest (short-circuit).

### B3. Portfolio view — `portfolio-kanban` (new)

- Reads: all `parallel-kanban.md` and `traceability-matrix.md` across active specs.
- Writes: single `portfolio-kanban.md` at repo root with:
  - Feature-level status cards (done / in-progress / ready / blocked counts per feature)
  - Cross-feature dev capacity heat map (who's committed across how many specs)
  - Ship-date forecast per feature with confidence band (low/med/high based on open-blockers + discovery backlog)
  - Cross-feature dependency graph (tasks that block tasks in other specs)
- **Cut per Director review:** Gantt is gone. Replaced with a one-line forecast + confidence per feature.

### B4. Source-of-truth integration — wire + extend `board-sync`

- **Wire (no code change):** Insert `board-sync` into `feature-build.pipeline.yaml` after `parallel-kanban` and into `spec-amend.pipeline.yaml` after `spec-evolve --section`.
- **Schema extension to `board-mapping.json`:** add a `pinned_sections` block per task so each Jira/Linear card description embeds `spec#AC-X@sha` and knows its pinned context:
  ```json
  "tasks": [{
    "task_id": "TASK-014",
    "work_item_id": "AB#12114",
    "pinned_sections": {
      "spec#AC-8": "sha-abc123",
      "plan#PHASE-3": "sha-789xyz"
    }
  }]
  ```
- **Delta push mode:** compare current section hashes vs `pinned_sections`; push only changed sections to the ticket description (vs re-rendering full task body on every sync).
- Stops the markdown-island problem: PM/design/compliance see the same truth, with SHA-level change tracking.

### B5. Velocity modeling — `config/team-velocity.yaml` (seeded by `feedback-loop`)

```yaml
developers:
  Karan:  { Go: 1.0, React: 0.4, Python: 0.8 }
  Mahesh: { Go: 0.5, React: 1.2, Python: 0.7 }
  Anita:  { Go: 0.9, React: 0.9, Python: 1.0 }
```

- Humans set initial coefficients. Reviewed quarterly.
- `feedback-loop` already emits `pipeline-calibration.json` with per-task-type, per-size, per-domain factors (existing behavior). After N≥3 pipelines, `feedback-loop` additionally emits **per-developer** calibration if task-implementer reports carry author attribution — `team-velocity.yaml` gets auto-updated suggestions (human approves before commit, no silent overwrites).
- `parallel-kanban` multiplies base effort (XS=0.5d...) by assigned dev's coefficient for the task's stack tag.
- Stack tags derived from `files to touch` patterns in `tasks.md`.
- Day-1 (no feedback data): human estimates stand alone. Day-30: calibrated.

### B6. NFR first-class — enhance `traceability-gen`

- ACs get `kind: functional | security | perf | compliance` tags in spec front-matter.
- Matrix renders security/compliance ACs with 🔴 badge.
- Changes to 🔴 ACs in an ADR auto-trigger `security-audit` as a pipeline step.
- Compliance AC breaks = auto-block PR via `approval-workflow-auditor`.

### B7. Instrumentation — wire + extend `feedback-loop`

- **Wire (no code change for existing analyses):** append to every `/run-pipeline` execution. Existing outputs (estimation calibration, failure patterns, gate effectiveness, spec stability, skill ranking) stay as-is.
- **Extend Phase 0 data collection:** add two new input sources:
  - `reports/briefing-delta-*.md` → new metric: `briefing_rework_rate` (% of PRs with scope drift from briefing).
  - `reports/briefing-freshness-check-*.md` → new metric: `briefing_staleness_rate` (% of dev sessions that hit a stale briefing).
- **Extend spec stability signal:** count `discovery-queue` entries per spec alongside existing revision-count signal. High discovery rate = planning-phase gaps.
- **Per-developer calibration:** feeds `config/team-velocity.yaml` suggestions (B5 above).
- Weekly roll-up feeds the pilot gate (B8).

### B8. Pilot gate (process, not code)

Before rolling these skills repo-wide: **2 features × 6 devs × 1 sprint pilot.**

Hard criteria (from `feedback-report`):
| Metric | Threshold |
|---|---|
| Cycle time (briefing→merged) | ≥25% reduction vs 2-sprint baseline |
| Briefing-delta rework rate | ≤5% of PRs |
| Token cost per task (all-in) | ≤60% of baseline |
| Dev NPS | ≥ +20 |

Owner: single named maintainer (to be assigned before pilot). Rollback plan: revert `feature-build.pipeline.yaml` to pre-amend version; skills stay installed, just not auto-invoked.

---

## Rollout sequence

**Phase 1 — Pilot unblocker (must ship):** extend `spec-evolve` with `--section` mode, add `discovery-queue` + `amendment-gate` + `briefing-freshness-check` (new), wire `board-sync` + `feedback-loop` into the pipeline. Proves the amendment loop + accountability. Pilot runs on new specs only (no backfill required).

**Phase 2 — Director scale (after pilot passes):** `portfolio-kanban` + `briefing-delta` (new), `team-velocity.yaml` + `feedback-loop` calibration extension, NFR tagging in `spec-gen` + `traceability-gen`, `board-sync` `pinned_sections` schema + delta push mode. Extends to multi-feature ops.

**Phase 3 — Migration + polish:** run `setup/backfill-section-index.sh` on existing specs; extend `quality-gate` to validate `SECTION_PATCH` blast radius; deprecate full-regen fallback once coverage confirmed.

---

## Pipeline wiring

`pipelines/developer/feature-build.pipeline.yaml` — updated chain:
```
spec-gen → plan-gen → task-gen → wave-scheduler
    → [traceability-gen ∥ parallel-kanban ∥ task-briefing-gen]
    → board-sync
    → task-implementer
    → briefing-delta
    → spec-review → review-fix
    → feedback-loop
```

`pipelines/developer/spec-amend.pipeline.yaml` — new:
```
discovery-queue (lint)
    → amendment-gate (human approval)
    → spec-evolve --section (fan-out over accepted ADRs)
    → briefing-freshness-check
    → board-sync (delta push)
    → feedback-loop
```

---

## Files to create

| Path | Purpose |
|------|---------|
| `skills/discovery-queue/{skill.yaml, prompt.md}` | Lint + append discoveries |
| `skills/amendment-gate/{skill.yaml, prompt.md}` | Human-approved batch wrapper over `spec-evolve --section` |
| `skills/briefing-freshness-check/{skill.yaml, prompt.md}` | SHA-pinned staleness check |
| `skills/briefing-delta/{skill.yaml, prompt.md}` | PR-time scope-vs-briefing check |
| `skills/portfolio-kanban/{skill.yaml, prompt.md}` | Cross-feature Director board |
| `pipelines/developer/spec-amend.pipeline.yaml` | Amendment pipeline |
| `config/team-velocity.yaml` | Per-dev velocity coefficients (human-seeded, feedback-loop-calibrated) |
| `setup/backfill-section-index.sh` | One-shot migration: synthesize `sections:` front-matter for legacy specs |

## Files to modify

| Path | Change |
|------|--------|
| `skills/spec-gen/prompt.md` | Emit `sections:` front-matter with IDs + normalized content hashes; tag ACs with `kind: functional\|security\|perf\|compliance` |
| `skills/plan-gen/prompt.md` | Emit section front-matter; cite `spec#AC-X@sha` |
| `skills/task-gen/prompt.md` | Emit section front-matter; cite `spec#AC-X@sha` and `plan#PHASE-X@sha`; surface stack tags from `files to touch` |
| `skills/task-briefing-gen/prompt.md` (from three-skills plan) | Stamp `pinned_sections` block; reference-by-sha not line-range |
| `skills/traceability-gen/prompt.md` (from three-skills plan) | Read AC `kind`; 🔴 badges on compliance/security; trigger `security-audit` step when compliance AC changes |
| `skills/parallel-kanban/prompt.md` (from three-skills plan) | Cut Gantt; apply velocity coefficients; forecast ship-date with confidence |
| `skills/spec-evolve/prompt.md` | Add `--section <ID>` mode; add `SECTION_PATCH` to blast-radius enum; add `discovery-queue` to trigger enum; extend `reprocess-manifest.json` schema with `section_patches:` list |
| `skills/board-sync/prompt.md` | Extend `board-mapping.json` schema with per-task `pinned_sections`; add delta push mode that compares pinned vs current section hashes |
| `skills/feedback-loop/prompt.md` | Extend Phase 0 to read `briefing-delta-*.md` and `briefing-freshness-check-*.md`; emit `briefing_rework_rate` + `briefing_staleness_rate`; per-dev calibration for `team-velocity.yaml` |
| `skills/quality-gate/prompt.md` | Validate `SECTION_PATCH` blast radius doesn't silently touch sections outside ADR's `affects:` list |
| `pipelines/developer/feature-build.pipeline.yaml` | Insert `board-sync`, `briefing-delta`, `feedback-loop` as shown |
| `registry/catalog.yaml` | Register 5 new skills (discovery-queue, amendment-gate, briefing-freshness-check, briefing-delta, portfolio-kanban); add `compliance-ac` capability |
| `CLAUDE.md` (repo) | Bump skill count; document amendment loop + section-addressing |

---

## Roleplay validation (3-dev team + Director)

Team: Mahesh, Karan, Anita on NutriKids. Director: Manoj.

### Scene 1 — Karan discovers "Docker > VM" mid-TASK-014
Old flow: fresh Cursor window, "redo spec for Docker," 36k tokens, blows away Manoj's annotated estimates, Anita's in-flight briefing invalidated silently.

New flow: Karan appends to `discoveries.md` (4 lines, <1k tokens):
```
DISC-012: Docker > VM for local runtime.
Found in: TASK-014.  Raised by: Karan, 2026-04-18.
Suggested impact: AC-8, PHASE-3.
```
Continues TASK-014 with local Docker. Pushes at EOD. **Cost: ~0.5k.**

### Scene 2 — Manoj runs `/amendment-gate` next morning
3 discoveries queued. Skill reads them, computes impact via section index, presents:
```
DISC-012: Docker > VM. Affects: AC-8, PHASE-3, tasks [014, 017, 022].
  Patch preview: spec §8 (-3/+8), plan §3 (-4/+12), 3 task cards → stale.
  Briefings affected: TASK-017, TASK-022 (not TASK-014 — Karan self-authored).
  [A]ccept / [R]eject / [D]efer:
```
Manoj types `A`. `amendment-gate` writes DEC-007 to decision-log, then invokes `spec-evolve --section --trigger discovery-queue --source DISC-012` for each affected section (3 sections only, ~7k). `spec.v2.md` emitted with 3 changed-hash sections in front-matter; untouched sections keep prior hashes. `reprocess-manifest.json` includes `section_patches:` list. Flags T-017, T-022 briefings 🟠. `board-sync` delta-pushes 3 Jira tickets with new ADR link + pinned-section update. **Cost: ~14k (vs 26k full-file revise, vs 36k cascaded regen).**

### Scene 3 — Anita opens fresh window for TASK-022
`briefing-freshness-check` fires first. Pinned `spec#AC-8@abc123` vs current `@def456`. Blocks:
```
❌ Briefing stale. AC-8 changed after briefing generated (DEC-007, 2026-04-18).
   Regenerate: /task-briefing-gen TASK-022 --refresh
```
Anita regenerates (~3k incremental, reads patched section only). Implements. Commits. **Cost: ~3.5k extra vs ignoring staleness.**

### Scene 4 — PR opens for TASK-022
`briefing-delta` runs. Compares briefing DoD (3 items) to PR diff. All 3 covered, no scope creep. Report: ✅ in-scope. Merges. **Cost: ~2k.**

### Scene 5 — Manoj's Friday portfolio review
Opens `portfolio-kanban.md`:
- **NutriKids:** 22/38 done. Confidence HIGH. 0 compliance flags.
- **ParentDash:** 5/15. Confidence MED. TASK-03 blocking 7 downstream; Anita leave Tue-Thu next week.
- **Insights:** 12/20. Confidence LOW. 3 discoveries pending amendment-gate.

Decision: reassign Karan 20% from NutriKids to Insights to clear discovery backlog. Logs to `decision-log.md` as DEC-009 (portfolio-level). **Cost: ~6k.**

### Scene 6 — Compliance AC hit
Karan's TASK-014 touches AC-8 (kind=compliance). `traceability-gen` had flagged AC-8 🔴. The amendment in Scene 2 auto-triggered `security-audit` as part of `spec-amend.pipeline`. Audit found one missing consent-check path. PR blocked by `approval-workflow-auditor` until owner-of-compliance (legal-designated engineer) approves. **Cost: ~8k for audit, ~0 for block (it's a pipeline gate).**

### Validation findings (bake into prompts)
- **`amendment-gate` MUST require human approval.** Auto-apply converts the whole loop into a regression machine.
- **Stale flag MUST block, not warn.** Warn-only during pilot reintroduced the "dev missed it" failure mode.
- **`discovery-queue` MUST accept partial info.** Dev rarely knows full impact; the gate computes `affects:` on approval using the section index.
- **`portfolio-kanban` MUST tolerate in-progress specs.** Feature without `tasks.md` = "planning" status, not "broken."
- **Section hashes MUST be content-only**, not mtime. Whitespace/reflow changes shouldn't flag downstream.
- **`briefing-delta` MUST skip on SHA match.** Running it on every PR when nothing drifted is pure waste.

---

## Token budget

### Cost of a single mid-implementation discovery (Docker/VM)

| Approach | Tokens |
|---|---|
| Old: cascaded full regen (spec + plan + tasks) | ~36k |
| Current `spec-evolve revise` (full-file version, downstream DELTA) | ~26k |
| New: discovery + amendment-gate + `spec-evolve --section` (3 sections) | ~6–8k |
| + `briefing-freshness-check` (2 briefings) + 2 refreshes | +7k |
| + `board-sync` delta push (3 tickets) | +2k |
| **New total** | **~17k (53% reduction vs cascaded, 35% vs current revise)** |

### Per-sprint all-in (20 tasks, 3 discoveries, 6 devs)

| Line item | Tokens |
|---|---|
| Initial pipeline (from three-skills plan) | 253k |
| 3× amendment cycles (Docker-like) | 3 × 17k = 51k |
| `portfolio-kanban` weekly (×4) | 4 × 6k = 24k |
| `board-sync` weekly delta (×4) | 4 × 3k = 12k |
| `feedback-loop` weekly (×4) | 4 × 3k = 12k |
| `briefing-delta` per PR (×20, ~60% short-circuit on SHA match) | 20 × 0.8k avg = 16k |
| `briefing-freshness-check` per session (×40) | 40 × 0.3k = 12k |
| **Sprint total (new world)** | **~380k** |

**Baseline (no framework, with 3 mid-sprint cascaded rewrites):** 400k + 3×36k = **508k**.

**Net: ~25% total sprint reduction, 53% on the discovery loop specifically.**

The headline is still that per-dev session input stays at ~3.5k (briefing + incremental patches), not ~20k (re-reading whole spec/plan/tasks).

### Token-reduction tactics (on top of three-skills tactics)

1. **Section-level content hashes** — skip-if-unchanged at section granularity. Unrelated edits to spec don't invalidate downstream tasks.
2. **Batched amendment-gate** — 3 discoveries in one gate run = 1 × (read+patch+sync), not 3. Amortizes the fixed cost.
3. **`board-sync` delta mode** — push only changed section SHAs to Jira, not full re-render.
4. **`portfolio-kanban` reads summaries, not artefacts** — each feature's kanban has a top-level `summary:` front-matter block (≤1.5k); portfolio rolls up summaries, not whole files.
5. **`briefing-delta` short-circuits on SHA match** — majority of PRs won't have drift; skip LLM entirely.
6. **`feedback-loop` samples pipeline logs, not artefacts** — logs are smaller and already structured.
7. **`spec-evolve --section` emits tabular diffs, not regenerated prose** where the change is structural (dep list, file list, DoD bullet). LLM only for genuine narrative edits.
8. **Staleness as signal, not regen** — the biggest saving. 🟠 flags cost ~0 tokens; full regen costs 20k+. Human decides when to cash the flag.

---

## Out of scope (explicit)

- **Real-time Jira push on every commit.** `board-sync` runs at pipeline gates + amendment-gate, not per-commit.
- **Cross-repo portfolio view.** Single-repo for v1. Multi-repo is a v2 if the pattern holds.
- **Auto-rollback on broken compliance AC.** Auto-block PR only. Rollback stays human-call.
- **AI-suggested velocity coefficients.** Humans set them; skill reads them. Resist the temptation.
- **Migration of existing specs to section-addressing.** Phase 3. For the pilot, new specs only.
- **Conflict resolution between two concurrent amendment-gates.** Assumed serialized by human; locking added only if it breaks in practice.

---

## Risks + mitigations

| Risk | Mitigation |
|---|---|
| Section-addressing migration breaks existing specs | Phase 3 only, via `setup/backfill-section-index.sh` with dry-run + diff mode. Pilot uses new specs only |
| `amendment-gate` becomes a human bottleneck | Allow `--auto-defer` for lead's absence; non-critical discoveries park in queue; hard cap: gate must run ≥2×/week |
| Devs skip `discoveries.md` and just "fix it in code" | `briefing-delta` at PR time catches scope creep; repeat offenders surface in `feedback-loop` report |
| Section hashes churn from whitespace or reformatting | **Design principle 6** — hash on canonical normalized content; add a regression test on the hasher to lock behavior |
| `spec-evolve --section` silently touches sections outside ADR `affects:` list | `quality-gate` validator (see A2) rejects the patch if untouched-section hashes changed |
| Discovery-queue collides with `/task-implementer` ambiguity flow | Boundary per A5: blocking = auto-triage; non-blocking = discovery-queue. Documented in both prompts |
| `feedback-loop` per-dev calibration feels surveillance-y | Opt-in; team-velocity coefficients reviewed by lead before commit; no silent overwrites of human-set values |
| Jira/Linear schema doesn't support ADR links | `board-sync` writes ADR link in description field as a Markdown link; graceful degrade |
| Pilot criteria fail | Rollback plan is 1 PR (revert pipeline yaml); skills remain but uninvoked |
