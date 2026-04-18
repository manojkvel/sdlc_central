# Plan: Three new SDLC-Central skills for parallel-team execution

## Context

During the NutriKids workshop roleplay we hit three framework-level gaps between `task-gen` (which produces `tasks.md`) and `task-implementer`:

1. **No visual traceability.** `tasks.md` + `plan.md` + `spec.md` exist side-by-side, but there is no single picture showing "AC → Phase → Task." A reviewer can't answer "if we break AC-7, what breaks?" in one glance.
2. **`tasks.md` is not parallelization-friendly.** It's a flat list. `wave-scheduler` outputs a machine-readable `wave-schedule.md`, but there is no developer-facing Kanban/Gantt view showing *who can grab what right now*, *what's blocked on what*, and *what each dev has in their lane next*.
3. **Fresh sessions burn context.** Opening a new Cursor/Claude Code chat and asking it to implement TASK-010 means reading ~3000 lines of spec/plan/tasks before the agent writes a line of code. There is no per-task self-contained briefing.

These gaps showed up as static workshop artefacts (`traceability-matrix.md`, `parallel-kanban.md`, `task-briefings/TASK-*.md`) on the `feature/001-nutrition-app` branch. The user's directive is to **turn those one-offs into reusable skills in the framework**, so every spec-driven project gets them automatically.

Outcome: three new skills wired into `developer/feature-build.pipeline.yaml` so that between "plan approved" and "implementation starts," every team gets a traceability diagram, a Kanban board, and one briefing per READY task — no extra prompting.

---

## Recommended approach

Add three new skills under `skills/`, wire them into the feature-build pipeline after `wave-scheduler`, register them in the catalog and the developer role.

### Skill 1 — `traceability-gen` (category: `planning`)

**Purpose:** Given `spec.md` + `plan.md` + `tasks.md` in the same `specs/<NNN>-<slug>/` directory, emit `traceability-matrix.md` containing:
- A Mermaid `flowchart LR` with three subgraphs (ACs, Plan Phases, Tasks/Test-Tasks) and edges AC→Phase→Task. Partial-agent tasks shaded differently.
- A fan-out heat map table — which ACs touch the most phases/tasks (i.e. risk-concentration points).
- Reverse lookup: "if this file changes, what breaks?" (reads `Files to touch` lines from `tasks.md`).
- Coverage health check (ACs with no impl task, phases with no tasks, tasks unmapped to ACs).

**Inputs:** `argument_hint: "path/to/spec.md"` (skill resolves sibling `plan.md` + `tasks.md`).
**Roles:** `[developer, architect, tech-lead]`.

### Skill 2 — `parallel-kanban` (category: `pipeline-automation`)

**Purpose:** Given `tasks.md` + `wave-schedule.md` (plus optional `git log` to detect DONE tasks), emit `parallel-kanban.md` containing:
- A Mermaid `gantt` chart with one section per plan phase, wall-clock based on effort (XS=0.5d, S=1d, M=2d, L=3d, XL=5d) at configured parallelism.
- A Mermaid `flowchart` Kanban board with four columns: DONE (merged), IN-PROGRESS (has commit on branch but no completion marker), READY (all deps satisfied), BLOCKED (has unmet deps — annotated with the blocker IDs).
- Per-developer lanes table (if `--team dev1,dev2,dev3` passed, balance upcoming tasks across them).
- Handoff protocol section (how to move a card from READY→IN-PROGRESS→DONE and update the file).

**Distinct from `wave-scheduler`:** `wave-scheduler` outputs a *machine-readable* schedule consumed by `pipeline-orchestrator`. `parallel-kanban` outputs a *human-facing visual* for standups and disjointed sessions.

**Inputs:** `argument_hint: "path/to/tasks.md [--team name1,name2,...] [--parallelism N] [--update]"`.
**Modes:**
- default (full): reads tasks.md + wave-schedule.md + full git log. Writes complete kanban.
- `--update`: reads only prev kanban + `git log <last_synced_commit>..HEAD`. Applies delta. Prints hint to rerun `task-briefing-gen --all-ready` if new tasks moved to READY.

**Roles:** `[developer, scrum-master, tech-lead]`.

### Skill 3 — `task-briefing-gen` (category: `planning`)

**Purpose:** Given `tasks.md` + a TASK-ID (or `--all-ready`), emit `task-briefings/TASK-XXX.md` files. Each briefing is self-contained so a fresh chat session pastes it as the first message and can implement without reading spec/plan/tasks. Contents:
1. The AC (verbatim quote from `spec.md §5`) this task exists for.
2. The plan phase + architecture decisions (from `plan.md §2/§4`) it must honor.
3. "What's already done upstream" — reads completed upstream task IDs from git log / tasks.md status markers.
4. Exact files to CREATE/MODIFY + exact DoD (from the task card in `tasks.md`).
5. Copy-pasteable test and run commands (resolved from `plan.md` Phase X "Tests First" table).
6. Commit message template with `task:TASK-XXX` subject tag + downstream consumer (who unblocks when this merges).
7. Handoff notes stub (empty section the dev fills in post-task).

**Inputs:** `argument_hint: "path/to/tasks.md TASK-XXX | --all-ready"`.
**Cost discipline:** `--all-ready` batch mode reads spec/plan/tasks **once**, writes N briefings. Single-task mode is allowed but flagged as expensive. Briefings cite spec/plan by `file.md §N L42-48` rather than inline-duplicating content.
**Roles:** `[developer, tech-lead]`.

---

## Pipeline wiring

Edit `pipelines/developer/feature-build.pipeline.yaml` to add three steps after `schedule` and before `implement`. All three depend only on outputs that exist after `schedule`, so they can be parallelized by `pipeline-orchestrator`:

```yaml
- id: generate-traceability
  skill: traceability-gen
  args: "$INPUT"                         # spec.md path propagated from pipeline input
  depends_on: [break-tasks]
  description: "Emit visual AC → Phase → Task traceability matrix"

- id: generate-kanban
  skill: parallel-kanban
  args: "$break-tasks.output"            # tasks.md
  depends_on: [schedule]
  description: "Emit Gantt + Kanban board for parallel team execution"

- id: generate-briefings
  skill: task-briefing-gen
  args: "$break-tasks.output --all-ready"
  depends_on: [schedule]
  description: "Emit per-task self-contained briefings for fresh sessions"
```

Insert between the current `schedule` step (line 17) and `implement` step (line 19). `implement` keeps `depends_on: [schedule]` — no change needed to it, since the three new steps are additive.

No new gates — these are reporting/visual steps. Failure is non-blocking (they can warn but must not fail the pipeline).

---

## Files to create

| Path | Purpose |
|------|---------|
| `skills/traceability-gen/skill.yaml` | metadata: name, version, description, category=planning, argument_hint, roles |
| `skills/traceability-gen/prompt.md` | universal prompt: Phase 1 load spec/plan/tasks; Phase 2 build AC↔Phase↔Task graph; Phase 3 emit Mermaid + heat map + reverse lookup + coverage check |
| `skills/task-briefing-gen/skill.yaml` | metadata: category=planning |
| `skills/task-briefing-gen/prompt.md` | universal prompt: accept TASK-ID or `--all-ready`; read `spec.md`, `plan.md`, `decision-log.md` (if exists), `tasks.md`; write one `task-briefings/TASK-XXX.md` per READY task |
| `skills/parallel-kanban/skill.yaml` | metadata: category=pipeline-automation |
| `skills/parallel-kanban/prompt.md` | universal prompt: parse tasks.md + wave-schedule.md + git log; emit Gantt + Kanban mermaid + dev-lane table + handoff protocol |

Pattern to follow: `skills/wave-scheduler/skill.yaml` and `skills/task-gen/prompt.md` (already read during Phase 1 exploration). `skill.yaml` schema = 6 fields (name/version/description/category/argument_hint/roles). `prompt.md` follows the "CRITICAL RULES → Phase 0 Load Inputs → Phase 1…N → Output" skeleton used by `wave-scheduler`.

Seed the prompt.md content from the already-written workshop examples under `docs/workshop/2026-04-17-nutrition-app/specs/001-nutrition-app/` (`traceability-matrix.md`, `parallel-kanban.md`, `task-briefings/TASK-010.md`, `task-briefings/TASK-006.md`) — strip NutriKids specifics, generalize to templates.

## Files to modify

| Path | Change |
|------|--------|
| `registry/catalog.yaml` | (a) Append `traceability-gen` to `categories.planning.skills`; append `task-briefing-gen` to `categories.planning.skills`; append `parallel-kanban` to `categories.pipeline-automation.skills`. (b) Add three new skill entries in the `skills:` block (alphabetical position: after `task-gen`, after `pipeline-orchestrator`, new slot for `traceability-gen`). (c) Add three skills to `roles.developer.skills` (bump `skill_count` 23→26); add `parallel-kanban` and `task-briefing-gen` to `roles.scrum-master.skills` (bump 14→16). `tech-lead.skills: all` auto-includes. |
| `pipelines/developer/feature-build.pipeline.yaml` | Insert three new steps between `schedule` and `implement` as shown above. |
| `adapters/claude-code/templates/CLAUDE.md.developer` | Bump "Your Skills (20)" → (23). Add three bullet lines under **Build from Spec**:<br>`- /traceability-gen specs/NNN/spec.md` — Visual AC→Phase→Task matrix<br>`- /parallel-kanban specs/NNN/tasks.md` — Gantt + Kanban board for parallel execution<br>`- /task-briefing-gen specs/NNN/tasks.md TASK-XXX` — Self-contained briefing for fresh session.<br>Update **Feature Build** chain annotation to: `task-gen → wave-scheduler → traceability-gen ∥ parallel-kanban ∥ task-briefing-gen → task-implementer → spec-review → review-fix`. |
| `adapters/claude-code/templates/CLAUDE.md.scrum-master` | Add `/parallel-kanban` and `/task-briefing-gen` entries; bump skill count. |
| `adapters/claude-code/tool-mappings.yaml` | No override needed — `planning` and `pipeline-automation` category defaults already include Read/Write/Grep/Glob/Bash(git log…). Confirm by re-reading lines 7–17. |
| `CLAUDE.md` (repo root) | Bump "61 skills" → "64 skills" in the What-This-Is paragraph and in the Key Commands `install-all.sh` description. |

## Adapter regeneration

After the new skill files exist, run the adapter to regenerate the Claude Code SKILL.md files (the generated files under `.claude/skills/` are already the installed form for this repo):

```bash
bash adapters/claude-code/adapter.sh . . traceability-gen task-briefing-gen parallel-kanban
```

Cursor adapter regeneration (if user has installed for cursor locally):

```bash
bash adapters/cursor/adapter.sh . . traceability-gen task-briefing-gen parallel-kanban
```

These scripts are idempotent — they read `skill.yaml` + `prompt.md` and write `.claude/skills/<name>/SKILL.md` and `.cursor/rules/sdlc-<name>.mdc` respectively. No manual edits to the generated files.

## Existing patterns to reuse

- **Skill file layout:** `skills/wave-scheduler/` (skill.yaml 6 fields, prompt.md CRITICAL RULES + phased structure) — `skills/wave-scheduler/skill.yaml` and `skills/wave-scheduler/prompt.md`.
- **Argument parsing in prompt.md:** `skills/wave-scheduler/prompt.md` lines 18–58 show how to parse `--max-parallel N` flags inside a prompt — reuse this style for `parallel-kanban`'s `--team` and `--parallelism` flags.
- **Output artefact examples to generalize:** `docs/workshop/2026-04-17-nutrition-app/specs/001-nutrition-app/traceability-matrix.md` (157 lines) and `parallel-kanban.md` (197 lines) — these were written by hand this session; they are the canonical output templates.
- **Pipeline step shape:** `pipelines/developer/feature-build.pipeline.yaml` lines 7–40 show `id / skill / args / depends_on / description / gate` — copy this.
- **Role skill list pattern:** `registry/catalog.yaml` lines 529–558 (developer) — alphabetical within functional sub-groups but not strictly sorted; append is fine.

## Verification

End-to-end test on a disposable branch:

1. **Syntax:** After writing files, confirm YAML parses:
   ```bash
   python -c "import yaml,glob;[yaml.safe_load(open(f)) for f in glob.glob('skills/*/skill.yaml')+['registry/catalog.yaml','pipelines/developer/feature-build.pipeline.yaml']]"
   ```
2. **Adapter regenerates:** Run `bash adapters/claude-code/adapter.sh . . traceability-gen task-briefing-gen parallel-kanban` and confirm `.claude/skills/traceability-gen/SKILL.md` etc. exist with correct frontmatter.
3. **Skill invocation dry-run:** From repo root, invoke each new skill against the workshop artefacts on `feature/001-nutrition-app`:
   ```
   /traceability-gen docs/workshop/2026-04-17-nutrition-app/specs/001-nutrition-app/spec.md
   /parallel-kanban docs/workshop/2026-04-17-nutrition-app/specs/001-nutrition-app/tasks.md --team Mahesh,Karan,Anita
   /task-briefing-gen docs/workshop/2026-04-17-nutrition-app/specs/001-nutrition-app/tasks.md --all-ready
   ```
   Expected: regenerated `traceability-matrix.md`, `parallel-kanban.md`, and one `task-briefings/TASK-XXX.md` per READY task — byte-compare against the hand-written versions and diff to confirm the skill reproduces the structure.
4. **Pipeline dry-run:** `/run-pipeline developer/feature-build docs/workshop/2026-04-17-nutrition-app/specs/001-nutrition-app/plan.md` — confirm the three new steps appear in the execution log with `PASS` and produce artefacts.
5. **Install-role smoke test:** `bash setup/install-role.sh developer --agent claude-code` into a throwaway directory; confirm the three new SKILL.md files land under `.claude/skills/` and `/traceability-gen` is listed when running `/help`.
6. **Catalog consistency:** `grep -c "^  - name:" registry/catalog.yaml` should equal the sum of skill-count across categories — add 3 to baseline.

---

## Roleplay validation — 3-dev handoff on the NutriKids backlog

Team: **Mahesh, Karan, Anita**. Branch: `feature/001-nutrition-app`. Spec has 10 ACs, plan has 7 phases, tasks.md has 38 tasks.

### Scene 1 — Plan approved, pipeline fires
Karan runs `/run-pipeline developer/feature-build specs/001-nutrition-app/plan.md`. `task-gen` writes `tasks.md` (38 tasks). `wave-scheduler` writes `wave-schedule.md` (13 waves). Then the three new skills fan out in parallel: `traceability-matrix.md`, `parallel-kanban.md`, and `task-briefings/TASK-00{1..6}.md` (the initial READY set). Total wall-clock for the three reporting steps ≈ longest single step, not sum.

### Scene 2 — Morning standup (all three on Zoom with the Kanban file open)
Nobody opens tasks.md. Mahesh sees his lane in §3 of `parallel-kanban.md`: T-010 → T-011 → T-015. Anita sees T-021 → T-012 → T-033. Karan is mid-flight on T-004. Standup runs in 4 minutes: "Mahesh grabs T-010, Anita grabs T-021, Karan finishes T-004 today." No "what's blocked?" discussion — the BLOCKED column is the authoritative answer.

### Scene 3 — Mahesh opens a fresh Cursor window for TASK-010
He pastes: `Pick up TASK-010 using briefing task-briefings/TASK-010.md. Branch: feature/001-nutrition-app`. Cursor reads 250 lines, not 1050. Writes the Alembic migration + session test. Commits `task:TASK-010 meal_logs migration`. **Disjointed-session context problem is actually solved** — this is the step that proves the ROI.

### Scene 4 — Handoff trigger (the friction point found in roleplay)
Mahesh's commit unblocks T-011, T-012, T-024, T-019. He needs to:
1. Move T-010 card DONE in `parallel-kanban.md`.
2. Move the four now-ready cards to READY.
3. Regenerate the four briefings (each briefing's "Upstream done" section is now stale).

**Gap identified:** doing this by hand reintroduces the friction `parallel-kanban` was supposed to remove. **Fix:** `parallel-kanban` runs in an `--update` mode that reads git log since last run + current tasks.md, regenerates DONE/READY transitions, and at the end prints: `Hint: 4 tasks moved to READY — run /task-briefing-gen --all-ready to refresh briefings.` Briefings are regenerated as a batch, not on commit trigger (avoid magic). Document this loop explicitly in the Handoff Protocol section of the output.

### Scene 5 — Anita starts TASK-021 in a fresh Claude Code window
T-021 has only T-002 as a dependency (long-merged). Her briefing is stable — no regen needed between her plan-approval morning and now. She implements, commits, pushes. One clean commit, one unblocked downstream (T-022).

### Scene 6 — Karan hits a spec ambiguity on T-004
"If I misread the `consent.mechanism` flag semantics, what else breaks?" He opens `traceability-matrix.md` → §1 Mermaid graph shows AC-5 and AC-7 both flow through the consent phase; §2 fan-out heat map flags AC-7 as 🟠 wide (2 phases × 2 tasks). He knows to loop in Arjun (architect) before proceeding. **This scenario proves traceability-gen earns its cost in *review* contexts, not just at planning time.**

### Validation findings (amend the skill prompts)
- **`parallel-kanban` needs an `--update` mode** that reads only `git log <last_synced_commit>..HEAD` + current tasks.md. Store `last_synced_commit: <sha>` in parallel-kanban.md frontmatter.
- **`task-briefing-gen` must batch.** Running it 20 times for 20 briefings is a pathological cost (re-reads spec/plan/tasks 20×). `--all-ready` reads inputs once and writes N briefings.
- **Briefings must reference by file:line, not inline-duplicate** long spec quotes. "See spec.md §5 lines 42-48" beats a 200-token inline quote for AC traceability.
- **`traceability-gen` only regenerates when inputs changed.** Compare mtime of spec/plan/tasks to mtime of matrix file; skip with "cached" message otherwise.

---

## Token budget (practical AIDLC economics)

Per-artefact baselines for a typical project (NutriKids-sized):

| Artefact | Lines | ≈ Tokens |
|----------|-------|----------|
| spec.md | 300 | 5k |
| plan.md | 350 | 6k |
| tasks.md | 400 | 7k |
| wave-schedule.md | 200 | 3k |
| decision-log.md | 150 | 2.5k |
| task-briefing | 250 | 1.5k |

### Cost per skill invocation (input + output)

| Skill | Reads (input) | Writes (output) | Cost per run |
|-------|--------------|-----------------|--------------|
| `traceability-gen` | spec + plan + tasks = 18k | matrix = 3k | **~21k** |
| `parallel-kanban` (full) | tasks + wave-schedule + git log = 10k | kanban = 4k | **~14k** |
| `parallel-kanban` (--update) | prev kanban + git log since last = 4k | delta patch = 1k | **~5k** |
| `task-briefing-gen` (--all-ready batch of 5) | spec + plan + tasks + decision-log = 20.5k (once) | 5 × 1.5k = 7.5k | **~28k batch / ~5.6k per briefing** |
| `task-briefing-gen` (single) | 20.5k | 1.5k | **~22k** ← pathological if called N times |

### Net project cost vs. baseline

**Without these skills**, each of 20 developer sessions pays the full context-load tax:
- 20 × (spec + plan + tasks + code_output) = 20 × 20k = **~400k tokens**

**With these skills**, a 20-task project:
- 1× traceability-gen + 1 re-run when spec evolves = 2 × 21k = 42k
- 4× parallel-kanban (initial full + 3 --update passes across waves) = 14k + 3×5k = 29k
- 4× briefing batches (initial 5 + 3 incremental batches of 5) = 4 × 28k = 112k
- 20× dev sessions reading a 1.5k briefing + writing code = 20 × 3.5k = 70k
- **Total: ~253k tokens ≈ 37% reduction** vs. baseline.

**The real win is not the ledger — it's that per-dev session input drops from ~20k to ~3.5k**, keeping sessions inside the warm cache window and leaving context budget for actual implementation reasoning.

### Token-reduction tactics (bake these into the skill prompts)

1. **Deterministic emit, not LLM-generated, for pure transforms.** The Kanban table, Gantt section, reverse-lookup table, and file-changes list are all deterministic transforms of YAML/git data. Prompt.md should instruct: "emit these sections via tabular computation, not free-text generation." Saves ~40% of output tokens.
2. **Skip-if-unchanged cache.** Each skill checks input mtimes vs output mtime. Exit early with "cached" if outputs are fresher. Covers the common case of re-running the pipeline after an unrelated change.
3. **Incremental `--update` mode for `parallel-kanban`.** Reads only `git log` since the last sync sha (stored in YAML frontmatter). Drops input from 10k → 4k on every post-initial run.
4. **Batched briefing gen.** Always read spec/plan/tasks once, write N briefings. Never invoke per-TASK in a loop.
5. **Reference-by-line, not inline duplication.** Briefings cite `spec.md §5 L42-48`, not paste the content. Cuts briefing size ~30% (still self-contained because the briefing includes absolute file paths and line ranges; the fresh-session agent will read just those ranges, not the whole spec).
6. **Conditional pipeline execution.** Add `when: inputs_changed` to the three new pipeline steps so they skip on re-runs where spec/plan/tasks are untouched. The pipeline-orchestrator already supports this via mtime checks — just wire it.
7. **Parallel fan-out in pipeline.** Three new steps all depend on `schedule` only. Verify `pipeline-orchestrator` dispatches them concurrently so wall-clock ≈ max(21k, 14k, 28k) rather than sum = 63k.
8. **Opt-out flag for tiny specs.** `config/feature-build.yaml: visual_reports: auto` (default: enable for specs with ≥5 tasks; disable below).

These tactics are not nice-to-haves — they are **required** in the skill prompts so any framework user (not just this workshop) gets the token-efficient version. Add a "Cost Discipline" section to each new `prompt.md`.

---

## Out of scope (explicit)

- **`kanban-sync` live updater.** Earlier proposal suggested a skill that continuously re-reads git log and re-writes the Kanban board as commits land. Skipped for this iteration — `parallel-kanban` can be re-run on demand. Leave a TODO in its prompt.md §7 to add live-refresh later.
- **Cursor/other adapter automation.** Only claude-code adapter regen is called out above. Other adapters regen similarly but the user's active workflow is claude-code; they can re-run the others when needed.
- **New pipelines.** These three skills are wired into the existing `developer/feature-build` pipeline only. No new `role/pipeline.yaml` files. Scrum-master can invoke `/parallel-kanban` standalone.

