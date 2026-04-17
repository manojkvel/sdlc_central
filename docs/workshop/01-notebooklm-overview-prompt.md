# Video Generation Prompt — SDLC Central Overview

6–8 min 1080p 30fps MP4 explainer of **SDLC Central (SDLC-C)** — governed AI-DLC framework. Audience: mixed workshop (POs, architects, devs, QA, DevOps, tech leads, scrum masters, designers). Tone: calm practitioner-to-practitioner. No hype. VO ~145 wpm, lo-fi ducked. Navy #0B1F3B + amber #F5A623, white bg. 2D animated diagrams only.

## Scene 1 — Title (0:00–0:08)
On-screen: "SDLC Central — Governed AI-Assisted Delivery". Sub: "61 skills · 30 pipelines · 8 roles".

## Scene 2 — Problem (0:08–0:50)
Split-screen. L: chaotic chat w/ random prompts ("fix this", "add login") in red. R: structured pipeline w/ named gates in amber/green. L dissolves → R. VO: Teams adopting Claude Code/Cursor/Copilot/Windsurf/Gemini hit same wall — devs prompt differently, specs skipped, reviews ad-hoc. Output fast, process messier. SDLC-C wraps AI tools w/ real SDLC discipline.

## Scene 3 — What it is (0:50–1:30)
3 stacked layers assemble: (1) 61 skill tiles (spec-gen, plan-gen, task-gen, review, security-audit…); (2) 30 pipeline ribbons; (3) 9 adapter logos (Claude Code, Cursor, Copilot, Windsurf, Cline, Aider, Gemini, Antigravity, AGENTS.md). VO: Skills + Pipelines + Adapters. Install `bash setup/install.sh`. Invoke: slash cmd.

## Scene 4 — Roles & handoff (1:30–2:30)
8-lane swim diagram (PO, Arch, Dev, QA, DevOps/SRE, Tech Lead, Scrum Master, Designer), time L→R. Card `spec.md` originates in PO → slides to Arch → becomes `plan.md` → Dev → `tasks.md` → QA → DevOps → PO sign-off. VO: Artefact IS the handoff. No copy-paste, no Slack.

## Scene 5 — Gates (2:30–3:30)
Animated funnel. Spec enters top. Gate 1 green ✓. Gate 2 amber pause → loop "auto-recover: spec-evolve" → green. Side panel: Minimal (2 HITL, 40% cov) / Standard (3 HITL, 70% cov) / Strict (5 HITL, 85% cov + deep security audit + license + API contract). VO: Auto-recover first, escalate only when needed.

## Scene 6 — End-to-end (3:30–5:00)
Repo tree grows L as terminal R types real slash cmds. Feature: "multi-tenant RBAC".
- PO: `/run-pipeline product-owner/feature-intake` → `specs/001-rbac/spec.md`.
- Arch: `/run-pipeline architect/design-to-plan` → `plan.md` + decision-log (*why*).
- Dev: `/run-pipeline developer/feature-build` → task-gen → wave-scheduler → task-implementer (TDD) → spec-review.
- Pre-PR: `/run-pipeline developer/pr-workflow` (review + security-audit + test-gen).
- QA: release-validation. DevOps: deploy-verify + slo-sla-tracker.
- Incident? incident-triager + rollback-assessor one slash away.

## Scene 7 — AI-DLC done right (5:00–6:00)
2 panels → central "Shipped feature" node. L "Human owns": scope, trade-offs, approvals, rollback. R "AI handles": spec drafting, task breakdown, first-draft tests, vuln scan (OWASP 2025 + Agentic 2026), trend summaries, docs. VO: Humans decide. AI executes. Gates enforce.

## Scene 8 — Workshop (6:00–6:50)
4-step track lighting up: Install → Decide (`/feature-balance-sheet`) → Build (pipelines) → Reflect (`/feedback-loop` + `/report-trends`).

## Scene 9 — Close (6:50–7:30)
Repo tree close-up: `skills/`, `pipelines/`, `config/gate-config.json`. End card: "Ready when you are. → bash setup/install.sh".

## Rules
- Cuts ≤1 per 4–6s exposition; 2–3s in Scene 6.
- No talking-head footage.
- Slash cmds & paths verbatim.
- Burned-in captions matching VO.
