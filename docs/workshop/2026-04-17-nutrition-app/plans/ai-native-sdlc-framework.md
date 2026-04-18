# AI-Native SDLC — designed to scale from 1 dev to 500

> Framework design proposal, written in the voice of Andrej Karpathy. A third design point to compare against `three-new-skills-plan.md` (evolutionary extension of the existing framework) and `patch-driven-evolution-plan.md` (addressable artifacts + amendment loop). This one proposes a rebuild from first principles.

*Karpathy voice on.*

## The core thesis

Most SDLC frameworks scale badly because they scale *process*. I want to scale *visibility* and keep the **loop invariant**. Same 5 verbs at every size. Think of it like ML training: the loss function doesn't change from 1 GPU to 10,000 — the data-parallelism strategy does. Same here.

## The invariant loop

```
idea → draft → build → judge → ship → learn
  ↑_____________________________________|
```

Six verbs. `learn` is first-class — every iteration produces eval data, rework signals, discovery logs. That's the flywheel.

## The 5 primitives (the whole framework)

| Skill | Input | Output | When |
|---|---|---|---|
| `draft` | idea | section-addressable spec (ACs + NFRs + hashes) | every feature |
| `plan` | spec | implementation roadmap | only features >1 week / cross-module |
| `build` | spec (+plan) | PR with code + tests + inline decision log | every feature |
| `judge` | PR + spec | verdict + score + fix suggestions | every PR |
| `ship` | approved PR | merge + deploy + rollback plan | every PR |

Two meta-skills wrap the core:
- `route` — small classifier; predicts complexity; picks single-pass vs full loop
- `learn` — nightly evals, distillation candidates, drift detection

That's it. Old SDLC-Central's 60 skills either compress into one of these, or become **context compilers** (deterministic transforms, no LLM) or **views** (rendered markdown reports).

## Where requirements live

**One place: the repo.** Specs are Git-tracked Markdown — Git IS the version log. No `spec.v2.md` files; no parallel databases. A feature is a directory:

```
specs/NNN-feature-slug/
  spec.md               ← current (Git history = version log)
  plan.md               ← optional, complex features only
  discoveries.md        ← append-only observations
  decisions.md          ← ADRs
  evals/gold.jsonl      ← examples for this spec's skills
  reports/              ← build-log, judge-verdict, etc.
```

Requirements are **section-addressable** (stable IDs + content hashes in front-matter). Downstream artifacts cite by `spec#AC-7@sha`. Staleness = `git diff` on section hashes. Cheap.

For non-repo humans (PMs, legal): `board-sync` mirrors repo → Jira/Linear. **Repo is SoT. Jira is a view.** Never the other way round.

## Git branching — trunk-based, no Git Flow

- `main` — always deployable, CI green, the default branch
- `feat/NNN-slug` — one branch per spec, any team size
- No `develop`, no `release/*`, no `staging` branch

What changes with scale is **merge policy**, not branch topology:

| Scale | Merge policy |
|---|---|
| Solo | Direct push to main for trivial; `feat/` for non-trivial |
| Squad (5–10) | PR + `judge` pass + 1 human review |
| Team (20–50) | + compliance AC auto-routes to compliance reviewer; flaky-test gate |
| Org (50+) | + release-train cadence; CAB for cross-module PRs |

Same topology. More review density.

## Productivity + visibility per scale

The work is identical across scales. The visibility layer is what grows.

### Solo dev
`spec.md` + code + `ROADMAP.md` (3 bullets). Self-review via `judge`. Done.

### Squad (5–10)
Add: `portfolio-kanban.md` auto-generated nightly; Slack webhook on `ship`; standup = 5 min reading the kanban; quarterly `ROADMAP.md`.

### Team (20–50)
Add: `board-sync` → Jira mirror; weekly kanban snapshot to stakeholder channel; `judge` eval dashboard (quality over time per skill); quarterly OKRs with confidence bands per spec; director reads the portfolio, not individual features.

### Org (50+)
Add: `incident-detector` wired to post-deploy errors; org-level portfolio roll-up across squads; cross-squad dep graph; CAB for cross-module; per-squad distilled models on their codebase; yearly themes → half-year plans → quarterly specs.

## Communication & oversight — auto-populated from artifacts

**Rule:** every piece of oversight is a *view computed from the artifacts*, never a separate document a human has to write.

| Role | Sees | Via | Cadence |
|---|---|---|---|
| Dev | briefing + discoveries | files in spec dir | real-time |
| Tech lead | portfolio kanban | auto-generated | daily |
| PM | sprint state | Jira mirror via `board-sync` | real-time |
| PO | roadmap + confidence | `ROADMAP.md` + forecast | weekly |
| Director | org rollup | org portfolio view | weekly |
| Compliance | compliance-AC PRs | auto-ping on label | event |
| Exec | ship report | auto-generated from merged PRs | quarterly |

Nobody writes status reports. The repo is the status report.

## Delivery roadmaps — three zoom levels

1. **Year roadmap** — themes (not features). Owned by exec. ~5 themes.
2. **Quarter roadmap** — specs with confidence bands. Owned by PO. ~10 specs per squad.
3. **Sprint roadmap** — active specs + WIP limits. Owned by tech lead. Auto-derived from portfolio kanban.

**Confidence bands are computed, not guessed.** Inputs:
- Spec maturity (open ACs, open discoveries)
- Implementation progress (tasks DONE / total)
- Team capacity (velocity calibrated from past sprints via `learn`)
- Blocker count (dependency graph)

Re-forecast weekly. Publish the delta. If a ship date slips, the reason is traceable to a specific section or discovery — not "things came up."

## Evals are the real CI

Every skill ships with `evals/gold-examples.jsonl` (30–50 held-out input/output pairs) + a rubric or judge prompt. Edit `build/prompt.md` → CI runs evals → regression blocks the PR, improvement is visible in the dashboard. **This replaces unit tests for prompts.** Gold examples grow from production features. It IS the flywheel.

## The distillation path (month-by-month)

- **M1–3:** everything on Opus/Sonnet. Log every invocation.
- **M4:** ~1000 runs per skill sitting in `reports/`.
- **M5:** fine-tune Haiku or Llama-3-8B per skill.
- **M6:** ship distilled models behind same skill interface. **10× cheaper inference.**
- **M9:** private model zoo — `build-auth-service` is a different fine-tune from `build-react-component`. `route` picks the right one.

This is how you structurally beat "vibe coding burns tokens." Not prompt tricks — **model substitution for the narrow, repetitive 80%.**

## Scale-up matrix (whole framework, one page)

| Dim | Solo | Squad (5–10) | Team (20–50) | Org (50+) |
|---|---|---|---|---|
| Skills | 5 | 5 | 5 | 5 |
| Artifacts | `spec.md`, code | + discoveries, kanban | + Jira mirror, eval dash | + org kanban, incidents |
| Git | trunk + feat/ | + PR gate | + compliance routing | + release train |
| Review | self + judge | judge + 1 human | + specialist routing | + CAB |
| Comms | self-notes | Slack + kanban | + Jira, weekly snapshot | + exec dashboard |
| Roadmap | ROADMAP.md | quarterly doc | OKRs + confidence | yearly themes |
| Evals | ad-hoc | per-skill gold set | nightly CI | per-squad custom |
| Models | 1 Opus | + Haiku | distilled | per-codebase fine-tunes |
| HITL gates | 0 | 1 (compliance) | 2 (+migration) | 3 (+cross-module) |

**Invariant core. Growing visibility.**

## Non-negotiables (the discipline this demands)

- **Section addressing.** Specs have stable IDs + content hashes. Automation dies without it.
- **Evals per skill.** No prompt change without a regression check against gold examples.
- **Full logging.** Every invocation's input/output goes to the flywheel store. Storage is cheap; training data is priceless.
- **Trust the loop — fix the skill, not the process.** If humans add process to compensate for low skill trust, we've failed. Improve evals; remove process.

## What this kills from old SDLC-Central

- 55 of the 60 skills. Most compress into the 5 or become context-compilers/views.
- Multi-stage HITL gates. Keep ≤3, always for compliance / migration / cross-module.
- `spec-evolve` as a separate skill. Git is the evolution tracker. Editing a spec IS evolution.
- Separate `plan-gen` / `task-gen` / `wave-scheduler`. Collapse into `plan` with output tiers.
- Per-role CLAUDE.md templates. One template, parameterized by scale.

## First 30 days to prove it

- **Day 1–7:** ship 5 skills + 2 meta-skills. Strip ruthlessly.
- **Day 8–14:** `judge` eval dashboard + gold examples for `draft` and `build`.
- **Day 15–21:** run 3 real features through it end-to-end. Log everything.
- **Day 22–30:** measure against the old 60-skill flow on cycle time, token cost, eval scores. Decide: burn the old, or keep it as escape hatch for one edge case.

## Bottom line

**Scale your visibility layer, not your loop. Evaluate every prompt the way you evaluate every model. Distill aggressively. Trust Git. Let the artifacts produce the oversight.**

The best SDLC framework is the smallest one that still tells the PM what's shipping Friday.

*Karpathy voice off.*
