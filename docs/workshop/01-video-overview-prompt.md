# Video Generation Prompt — SDLC Central Framework Overview

> Paste this entire block into your video generation agent (Sora, Runway, Veo, Synthesia, HeyGen, etc.). It contains the full narrative script, scene-by-scene visual direction, on-screen text, voice-over tone, and timing. Total target length: **6–8 minutes**.

---

## SYSTEM / ROLE
You are a senior technical-explainer video producer. Generate a polished, corporate-quality explainer video that introduces the **SDLC Central** framework and its application to **AI-assisted Development Lifecycle (AI DLC)** practice — productivity-focused, NOT autonomous-agent hype. The audience is a workshop room of mixed roles: Product Owners, Architects, Developers, QA, DevOps, Tech Leads, Scrum Masters, Designers. Tone: confident, calm, practitioner-to-practitioner. Avoid buzzword salad and "agents will replace you" framing. Emphasize *governed productivity*: humans stay in the driver seat, AI removes drudgery and enforces consistency.

## OUTPUT FORMAT
- 1920×1080, 30fps, MP4
- Voice-over: neutral mid-pitch (male or female), ~145 wpm, conversational, no hard sell
- Background music: low-key ambient/lo-fi at -24 LUFS, ducks under VO
- On-screen text: sans-serif (Inter or similar), high contrast, max 7 words per overlay
- Color palette: deep navy (#0B1F3B) + warm amber accent (#F5A623) + soft white background for diagrams
- Subtle motion: 2D animated diagrams, gentle pans, NO stock-footage of people typing

## OPENING TITLE CARD (0:00–0:08)
**On-screen:** "SDLC Central — Governed AI-Assisted Delivery"
**Subtitle:** "61 skills. 30 pipelines. 8 roles. One framework."
**Visual:** Logo wordmark fades in over a faint isometric grid of lifecycle stages (spec → plan → tasks → impl → review → release).

---

## SCENE 1 — The problem we are solving (0:08–0:50)
**Voice-over:**
"Most teams adopting AI coding assistants hit the same wall. Each developer prompts differently. Specs are skipped. Reviews are inconsistent. Security checks happen — sometimes. The output is fast, but the *process* gets messier, not cleaner. SDLC Central exists to fix that. It is not another autonomous agent. It is a structured framework that wraps your existing AI tools — Claude Code, Cursor, Copilot, Windsurf, Gemini — with the discipline of a real software development lifecycle."

**Visual:**
- Split screen. Left: a chaotic developer chat scroll with random prompts ("fix this", "add login", "make it faster") — red.
- Right: a clean, structured pipeline diagram with named stages and gates — amber/green.
- Transition: left side dissolves into right side.

**On-screen text bullets:** "Inconsistent prompts" → "Skipped specs" → "Ad-hoc reviews" → "Variable quality"

---

## SCENE 2 — What SDLC Central is, in one breath (0:50–1:30)
**Voice-over:**
"At its core, SDLC Central gives your team three things. **Skills** — sixty-one reusable, prompt-engineered building blocks like spec-gen, plan-gen, security-audit, review. **Pipelines** — thirty pre-wired chains of those skills, organized by role, with quality gates between every stage. And **Adapters** — so the same skill works identically whether your developer uses Claude Code or your designer uses Cursor. Install once with a shell script. Invoke with a slash command."

**Visual:**
- Three stacked layers, animated to assemble:
  1. Bottom: grid of 61 small tiles labelled with skill names (spec-gen, plan-gen, task-gen, review, security-audit, …).
  2. Middle: 30 pipeline ribbons connecting tiles.
  3. Top: 9 adapter logos (Claude Code, Cursor, Copilot, Windsurf, Cline, Aider, Gemini, Antigravity, AGENTS.md).

**On-screen text:** "Skills · Pipelines · Adapters"

---

## SCENE 3 — The 8 roles and how they hand off (1:30–2:30)
**Voice-over:**
"The framework recognises that software is a team sport. It ships role-tailored installs for eight roles: Product Owner, Architect, Developer, QA, DevOps and SRE, Tech Lead, Scrum Master, and Designer. Each role gets only the skills they need. Each role's pipelines define what comes in, what goes out, and who picks it up next. A Product Owner finishes feature-intake; the spec is an artefact in the repository under `specs/`. The Architect's design-to-plan pipeline reads that exact file. No copy-paste, no Slack message, no lost context. The artefact *is* the handoff."

**Visual:**
- Horizontal swim-lane diagram, eight lanes top-to-bottom, time flowing left-to-right.
- An animated card labelled "spec.md" originates in the PO lane, slides into Architect, becomes "plan.md", slides to Developer, becomes "tasks.md", and so on through QA → DevOps → back to PO for sign-off.
- Brief pulse-highlight on each role as the card enters their lane.

**On-screen text:** "The artefact is the handoff."

---

## SCENE 4 — Quality gates, not vibes (2:30–3:30)
**Voice-over:**
"Between every stage sits a quality gate. The framework ships three profiles. **Minimal** for spikes and prototypes — two human approvals. **Standard** for normal work — three approvals. **Strict** for compliance-sensitive systems — five approvals, plus mandatory deep security audit, license audit, and API contract checks. A gate is not a checkbox. If a spec is missing acceptance criteria, the spec-to-plan gate fails, the framework auto-invokes spec-evolve to fix it, and only escalates to a human when machines have done all they reasonably can. This is governance that removes work, not adds it."

**Visual:**
- Animated funnel diagram. A "spec" object enters the top.
- Passes through gate 1 (spec-to-plan) — green check.
- Stuck at gate 2 — amber pause, small loop animation showing "auto-recover: spec-evolve", then green pass.
- Continues through plan-to-tasks → tasks-to-impl → impl-to-release.
- Side panel: three labelled boxes for the gate profiles, with their HITL counts (2 / 3 / 5) and threshold deltas (test coverage 40% / 70% / 85%).

**On-screen text:** "Auto-recover first. Escalate only when needed."

---

## SCENE 5 — Walking a real feature through the pipeline (3:30–5:00)
**Voice-over:**
"Let's watch a real feature flow end-to-end. A Product Owner has an idea: 'Add multi-tenant role-based access control.' She runs `/run-pipeline product-owner/feature-intake`. The framework asks a quick balance-sheet question — is this even worth building? It generates a structured spec under `specs/001-rbac/spec.md`. The quality gate confirms acceptance criteria, edge cases, and security constraints exist. The PO approves at the HITL gate.

The Architect picks it up — same repo, same file. He runs `/run-pipeline architect/design-to-plan`. Out comes `specs/001-rbac/plan.md`, with phases, file changes, risks. Decision-log captures *why* he chose the approach he did.

The Developer runs `/run-pipeline developer/feature-build`. Task-gen breaks the plan into atomic, TDD-first tasks. Wave-scheduler decides what can run in parallel. Task-implementer writes the code with tests first. Spec-review validates that every acceptance criterion was actually implemented.

Before the PR, `/run-pipeline developer/pr-workflow` runs review, security-audit, and test-gen. QA runs release-validation. DevOps runs deploy-verify and slo-sla-tracker watches for regressions. If something breaks, incident-triager and rollback-assessor are one slash command away."

**Visual:**
- Animated repo file tree on the left, growing as artefacts appear.
- Right side: a terminal showing the actual slash commands being typed.
- Each pipeline stage flashes as it executes; the tree gains `spec.md`, `plan.md`, `tasks.md`, `decision-log.md`, `implementation-report.md`, `code-review.md`, `security-audit.md`, `release-readiness.md`.
- Bottom progress bar shows position in the lifecycle.

**On-screen text (per stage):** "spec.md" → "plan.md" → "tasks.md" → "code + tests" → "audit ✓" → "release"

---

## SCENE 6 — AI DLC done right: productivity with guardrails (5:00–6:00)
**Voice-over:**
"This is what we mean by AI-DLC. Not autonomous agents shipping to production while you sleep. Humans still own the decisions that matter — what to build, when to ship, when to roll back. AI handles the work that scales poorly with humans — generating boilerplate specs, breaking plans into tasks, writing first-draft tests, scanning for known vulnerabilities, summarising trends across hundreds of pull requests. The result is a team that ships faster *and* with more discipline than before, not less. Same engineers. Same review culture. Better leverage."

**Visual:**
- Two panels.
- Left: "Human owns" — list of icons: scope, trade-offs, approvals, rollback decisions.
- Right: "AI handles" — list of icons: spec drafting, task breakdown, test scaffolding, security scan, trend analysis, doc generation.
- Both panels feed into a central node labelled "Shipped feature".

**On-screen text:** "Humans decide. AI executes. Gates enforce."

---

## SCENE 7 — How we'll use this in today's workshop (6:00–6:50)
**Voice-over:**
"In today's session, we will do four things. First, each of you installs the framework for your role with one shell command. Second, we pick three real ideas from our backlog and run them through `/feature-balance-sheet` to decide which is worth building. Third, we take the winner end-to-end — spec, plan, tasks, implementation, security audit, release notes — using the role hand-offs you just saw. Fourth, we run `/feedback-loop` and `/report-trends` to look at what the framework taught us about our own process. By the end of the day, you will have a working feature, a governed pipeline, and the muscle memory to do this on Monday morning."

**Visual:**
- A 4-step horizontal track, each step lighting up in turn:
  1. Install (terminal icon)
  2. Decide (balance sheet icon)
  3. Build end-to-end (pipeline icon)
  4. Reflect (dashboard icon)

**On-screen text:** "Install · Decide · Build · Reflect"

---

## SCENE 8 — Closing (6:50–7:30)
**Voice-over:**
"SDLC Central is open, agent-agnostic, and configurable to your team's risk appetite. The skills are version-controlled in your repo. The pipelines are YAML you can read and edit. The gates are JSON thresholds you can tune. There is nothing magical and nothing hidden. Let's get started."

**Visual:**
- Repo tree close-up showing `skills/`, `pipelines/`, `config/gate-config.json`.
- Final card fades in: "SDLC Central — see you in the workshop."
- Subtle wordmark watermark holds for two seconds.

**On-screen final card:** "Ready when you are. → bash setup/install.sh"

---

## STYLE & PACING NOTES (for the video agent)
- Cuts: max 1 every 4–6 seconds during exposition; faster (2–3s) during Scene 5 walk-through.
- No human face talking-head footage. This is a concept explainer, not a vendor pitch.
- Use real terminal text rendering (not stylised) when showing slash commands — viewers should be able to read and recognise them.
- All file paths and slash commands shown on screen MUST exactly match these strings:
  - `/run-pipeline product-owner/feature-intake`
  - `/run-pipeline architect/design-to-plan`
  - `/run-pipeline developer/feature-build`
  - `/run-pipeline developer/pr-workflow`
  - `/run-pipeline qa/release-validation`
  - `/run-pipeline devops-sre/deploy-verify`
  - `bash setup/install.sh`
  - `specs/001-rbac/spec.md`, `plan.md`, `tasks.md`, `decision-log.md`
- Do not invent skill names. Allowed skill names to display: spec-gen, plan-gen, task-gen, wave-scheduler, task-implementer, spec-review, review, review-fix, security-audit, security-audit-deep, test-gen, regression-check, release-readiness-checker, release-notes, incident-triager, rollback-assessor, slo-sla-tracker, feedback-loop, report-trends, feature-balance-sheet, decision-log, quality-gate, gate-briefing, spec-evolve, spec-fix.
- End-card dwell: minimum 2 seconds for legibility.
- Captions/subtitles: include burned-in English captions matching VO verbatim.

## DELIVERABLES EXPECTED FROM THE VIDEO AGENT
1. Final 1920×1080 MP4 (~7 min)
2. Caption file (.vtt or .srt)
3. A 30-second cut-down using only Scenes 1, 4, and 8 (for social / Slack share)
4. A still poster frame from Scene 3 (the swim-lane handoff diagram) — for use as a workshop slide background
