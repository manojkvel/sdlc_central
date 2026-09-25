# Atticus — governed AI delivery for any coding agent

*Named after Atticus Finch, who weighs the evidence and judges fairly: every claim is proved by a recorded run, and every decision is made by a named person and kept on record.*

Atticus is the AIDLC (AI-driven development lifecycle) layer of SDLC Central. It lets an AI
coding agent go fast while every step it takes stays planned, approved by a named person, proved
by real test runs, and auditable afterwards. You install it into a project as an extension to the
agent you already use: Claude Code, Cursor, GitHub Copilot, Windsurf, Cline, Aider, Gemini CLI,
Antigravity, Tabnine, or any agent that reads `AGENTS.md`.

> Status: `2.0.0-alpha`, on the `aidlc_framework` branch. Tested on macOS with bash 3.2.
> Linux and Windows paths are written to be portable but have not been run in CI yet.
> See [Known limitations](#known-limitations).

---

## Contents

1. [How it works in one minute](#how-it-works-in-one-minute)
2. [Quick start](#quick-start)
3. [Install](#install)
4. [Shell profile: global and local](#shell-profile-global-and-local)
5. [Using Atticus in your agent](#using-atticus-in-your-agent)
6. [Platform setup: macOS, Linux, Windows](#platform-setup-macos-linux-windows)
7. [Configure your project profile](#configure-your-project-profile)
8. [Core ideas: units, tiers, profiles, risk, gates](#core-ideas-units-tiers-profiles-risk-gates)
9. [Use cases, step by step](#use-cases-step-by-step)
10. [Artifacts: what is created and what to commit](#artifacts-what-is-created-and-what-to-commit)
11. [Sessions: stop, resume, continue](#sessions-stop-resume-continue)
12. [Human decisions](#human-decisions)
13. [Evidence and verification](#evidence-and-verification)
14. [Handoff](#handoff)
15. [Context management and token cost](#context-management-and-token-cost)
16. [Scorecard and release](#scorecard-and-release)
17. [Metrics, console and wiki](#metrics-console-and-wiki)
18. [CI and the decision bot](#ci-and-the-decision-bot)
19. [Update and uninstall](#update-and-uninstall)
20. [Troubleshooting: block codes](#troubleshooting-block-codes)
21. [Known limitations](#known-limitations)
22. [Credits](#credits)
23. [Command reference](#command-reference)

---

## How it works in one minute

Atticus runs four rails beside the agent's normal work:

| Rail | What it does | Where it lives |
| --- | --- | --- |
| **Main stream** | Skills and pipelines do the work: spec, plan, tasks, code, review, docs. | `<agent-dir>/skills`, `<agent-dir>/pipelines` |
| **Control** | Shell hooks block unsafe or out-of-order actions before they happen. | `<agent-dir>/hooks/aidlc-*` |
| **Evidence** | A recorder runs tests and keeps hashed logs. A verifier seals the result. | `.track/phases/<phase>/evidence/`, `VERIFICATION.md` |
| **Audit** | Every stage change, decision and artifact hash goes into an append-only log. | `.track/lineage.md`, `.track/human-decisions.md` |

Everything is plain files in your repository under `.track/`. There is no server, no database
and no network call. Enforcement is shell script, so it costs no model tokens.

The agent can never approve its own work. At each gate it stops and prints a checkpoint. A person
types an exact decision such as `APPROVE PLAN`. A hook records who decided, when, and the hash of
what they approved. If the approved file changes afterwards, the consistency check flags it.

---

## Quick start

```bash
# Once per machine: download Atticus and set up your shell
curl -fsSL https://raw.githubusercontent.com/manojkvel/sdlc_central/aidlc_framework/get-atticus.sh | ATTICUS_REF=aidlc_framework bash

# Once per project
cd ~/code/my-service
atticus init

# Every day
atticus go
```

That is the whole setup. `atticus init` finds your agent from the files in the project, asks your
role (developer by default), installs everything and creates `.track/`. `atticus go` opens your agent
where you left off. Inside the agent there is one command: `/atticus` followed by what you want.

Until the `aidlc_framework` branch is merged and pushed to `main`, use the branch URL and
`ATTICUS_REF` as shown. The other examples in this guide use the `main` URL.

---

## Install

### Prerequisites

| Tool | Needed for | Required |
| --- | --- | --- |
| bash 3.2 or newer | installers, hooks, tools | yes |
| `jq` | reading hook payloads, config and evidence | yes. Without it, hooks print a warning and allow. |
| `git` | lineage, CI, decision bot, install and update | yes |
| `shasum` or `sha256sum` | artifact hashes and seals | yes. Either one works. |
| `perl` | millisecond timing of evidence runs | optional |
| `node` 18+ | only this repository's own tests | optional |

`atticus doctor` checks all of these. `atticus doctor --fix` repairs what it can.

### The six commands

| Command | Where | What it does |
| --- | --- | --- |
| `atticus setup` | once per machine | Puts `atticus` on your PATH, adds a small block to your shell profile, turns on tab completion. |
| `atticus init` | once per project | Detects the agent, picks a role, installs skills, personas, pipelines and hooks, creates `.track/`. |
| `atticus go` | daily | Opens your agent on the project at the resume point. |
| `atticus update` | when you like | Pulls the latest Atticus, then refreshes this project. Your config and `.track/` are kept. |
| `atticus doctor [--fix]` | when something is off | Checks tools, PATH, hook integrity and the track root, and repairs them. |
| `atticus remove` | rarely | Removes Atticus from the project. `.track/` and `CLAUDE.md` are kept. |

Two more for occasional use: `atticus add <role>` adds a second role, and `atticus help all` lists
every command.

### `atticus init` options

Everything is optional. With no options, `init` detects and asks. Pass `-y` to accept all defaults
without questions, for example in scripts.

| Option | Effect |
| --- | --- |
| `--agent A[,B]` | Choose the agent instead of detecting it. |
| `--role R[,S]` | Choose roles instead of being asked. `all` installs every role. |
| `--tier 1\|2\|3` | Tier used when a unit does not declare one. Default 2. |
| `--hub` | Also create hub files for multi-team work (tier 3). |
| `--ci` / `--decisions` | Add the GitHub Actions checks, and the decision bot. |
| `--track-root P` | Put the track somewhere other than `.track/`. |
| `--no-hooks` | Skip hooks. The evidence and scorecard tools are still installed. |
| `-v` | Show the full installer output. |

**How the agent is detected.** `init` looks for each agent's files in the project: `.claude/` or
`CLAUDE.md`, `.cursor/`, `.github/copilot-instructions.md`, `.windsurf/`, `.clinerules`,
`.aider.conf.yml`, `GEMINI.md`, `.antigravity/`, `TABNINE.md`, `AGENTS.md`. If it finds none, it uses
the first agent command on your machine (`claude`, `cursor`, `gemini`, `aider`), else Claude Code.
If it finds several, it asks.

Roles: `developer`, `architect`, `qa`, `product-owner`, `devops-sre`, `tech-lead` (everything),
`scrum-master`, `designer`, `release-manager`. Every role gets `/atticus`, the eight personas and the
governed `aidlc/unit-of-work` pipeline.

### What lands where, per agent

| Agent | `--agent` | Skills and rules | Personas | Hooks and tools | Enforcement |
| --- | --- | --- | --- | --- | --- |
| Claude Code | `claude-code` | `.claude/skills/` | `.claude/agents/` (native subagents) | `.claude/hooks/`, wired in `.claude/settings.json` | **Enforcing.** Exit 2 blocks the tool call or prompt. |
| Cursor | `cursor` | `.cursor/rules/sdlc-*.mdc` | `.cursor/rules/aidlc-*.mdc` | `.cursor/hooks/` | Advisory |
| GitHub Copilot | `copilot` | `.github/copilot-instructions.md`, `.github/instructions/` | `.github/agents/*.agent.md` | `.github/hooks/` | Advisory |
| Windsurf | `windsurf` | `.windsurf/rules/` | `.sdlc/agents/` | `.sdlc/hooks/` | Advisory |
| Cline | `cline` | `.clinerules/` | `.sdlc/agents/` | `.sdlc/hooks/` | Advisory |
| Aider | `aider` | `CONVENTIONS.md`, `.aider.conf.yml`, `.sdlc/skills/` | `.sdlc/agents/` | `.sdlc/hooks/` | Advisory |
| Gemini CLI | `gemini` | `GEMINI.md` | `.sdlc/agents/` | `.sdlc/hooks/` | Advisory |
| Antigravity | `antigravity` | `.antigravity/rules/`, `.antigravity/workflows/` | `.sdlc/agents/` | `.sdlc/hooks/` | Advisory |
| Tabnine | `tabnine` | `TABNINE.md`, `.sdlc/skills/` | `.sdlc/agents/` | `.sdlc/hooks/` | Advisory |
| Any AGENTS.md agent | `agents-md` | `AGENTS.md` | `.sdlc/agents/` | `.sdlc/hooks/` | Advisory |

Pipelines go to `.claude/pipelines/`, `.cursor/pipelines/`, `.github/pipelines/` or
`.sdlc/pipelines/`. The installer records the agent, roles and hook level in `sdlc-central.json`,
which is in `.claude/` for Claude Code and in `.sdlc/` for every other agent.

**Enforcing versus advisory.** Only Claude Code exposes hook points that can block a write, a shell
command and a prompt. On every other agent the same scripts are installed, the pipeline runner calls
the approval guard and quality gate itself, and CI runs the checks on every pull request. Nothing
stops an advisory agent from writing outside the runner, so on those agents use `atticus init --ci`
and treat the pull request check as the enforcement point.

### Under the hood

`atticus` is a thin front for the scripts in `setup/`, which you can still call directly:
`install-role.sh`, `install-all.sh`, `init-track.sh`, `install-ci.sh`, `update.sh`, `uninstall.sh`.
The older interactive `setup/install.sh` menu and the npm package in `package/` predate Atticus and
do not install it.

---

## Shell profile: global and local

Atticus lives in two places, and it helps to keep them apart.

| Scope | What it holds | Where | Who has it |
| --- | --- | --- | --- |
| **Global** (your machine) | The `atticus` command, its tab completion, your decision name. Optionally `/atticus` and the personas for every Claude Code project. | `~/.atticus`, `~/.local/bin/atticus`, one block in your shell profile, optionally `~/.claude/` | You |
| **Local** (each project) | Skills, personas, pipelines, hooks, config and `.track/` | inside the repository | Everyone who clones it |

**The local part is committed**, so a teammate who clones the repository gets the hooks, personas
and state without installing anything. Their agent reads the project files directly. They need the
global `atticus` command only for conveniences such as `atticus go`, `status` and `update`.

**Hooks are never global.** Enforcement is always per project, turned on by `atticus init`. A
repository without `.track/` is never blocked, even if you set up global personas.

### What `atticus setup` writes

`atticus setup` detects your shell from `$SHELL`. Override it with `--shell zsh|bash|fish|pwsh`. It
links `~/.local/bin/atticus` (change it with `--bin`) and adds one marked block to your profile. It
never touches the rest of the file. Running it again replaces the block. `atticus setup --undo`
removes the block and the link.

**zsh** (`~/.zshrc`; the default shell on macOS):

```bash
# >>> atticus >>>
export ATTICUS_HOME="$HOME/.atticus"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
autoload -Uz compinit bashcompinit; (( $+functions[compdef] )) || compinit -i; bashcompinit
[ -f "$ATTICUS_HOME/completions/atticus.bash" ] && . "$ATTICUS_HOME/completions/atticus.bash"
# <<< atticus <<<
```

**bash** (`~/.bashrc`, Linux, WSL and Git Bash): the same block without the `autoload` line. Login
shells, such as macOS Terminal with bash, read `~/.bash_profile` instead. So on macOS, or when that
file exists, setup also makes sure it loads `~/.bashrc`.

**fish** (`~/.config/fish/conf.d/atticus.fish`): `set -gx ATTICUS_HOME …`, `fish_add_path`, and
simple completions.

**PowerShell**: setup prints a one-line function to paste into `$PROFILE`. It forwards to bash from
Git for Windows or WSL:

```powershell
function atticus { & bash "$env:USERPROFILE/.atticus/bin/atticus" @args }
```

Useful options:

| Option | Adds |
| --- | --- |
| `--name "Dana K"` | `export AIDLC_DECIDER="Dana K"`: the name recorded on decisions you type. Without it, your `git config user.name` is used. |
| `--global` | Installs `/atticus`, the pipeline runner and the eight personas into `~/.claude/` so they work in every Claude Code project. Setup also offers this when it sees `~/.claude`. |

Environment variables that Atticus reads:

| Variable | Default | Purpose |
| --- | --- | --- |
| `ATTICUS_HOME` | `~/.atticus` | Where the framework is cloned |
| `ATTICUS_REF`, `ATTICUS_REPO`, `ATTICUS_BIN` | `main`, GitHub URL, `~/.local/bin` | Bootstrap choices |
| `ATTICUS_YES` | unset | Set to 1 to accept defaults without questions |
| `AIDLC_DECIDER` | git user name | Your name on recorded decisions |
| `AIDLC_TRACK_ROOT` | from `sdlc-central.json` | Override the track root for one command |

---

## Using Atticus in your agent

You do not need to know persona, pipeline or skill names. Type `/atticus` and what you want. Atticus
reads the resume block, works out the intent, says in one line which persona it chose and why, and
acts.

```text
/atticus                                   carry on from where you stopped
/atticus status                            where things stand and who is blocking
/atticus add password reset by email       start a feature and draft the spec
/atticus login crashes on empty email      start a tier 1 fix and find the root cause
/atticus how does billing handle refunds   answer from the domain expert
/atticus is the plan complete              plan checker
/atticus prove it works                    verifier runs and seals the evidence
/atticus is this secure                    security reviewer
/atticus are we ready to ship              governance reviewer and the scorecard
/atticus hand this over to QA              delivery manager writes the handoff
```

How intent maps to personas:

| You want to | Persona |
| --- | --- |
| carry on | whoever `NEXT_ACTION_OWNER` names, through the orchestrator |
| build something new, judge value or scope | product strategist |
| understand the system or its rules | domain expert |
| check a plan | plan checker |
| prove it works | verifier |
| make it safe | security and standards reviewer |
| ship it, audit approvals | governance reviewer |
| hand over, report, escalate | delivery manager |
| coordinate with other teams | contract registry, then governance reviewer |

When two fit, the persona that owns the current stage wins. To choose yourself, say so:
`/atticus as security: review the token refresh`.

**Decisions are different.** Type them as a plain message, not after `/atticus`, for example
`APPROVE PLAN`. The approval guard reads the first line of your message, so anything before the
decision stops it being recorded.

How to call Atticus in each agent:

| Agent | Type | If it is not picked up |
| --- | --- | --- |
| Claude Code | `/atticus …` | Run `atticus doctor`. The skill is in `.claude/skills/atticus/`. |
| Cursor | `@sdlc-atticus …` | Reference `.cursor/rules/sdlc-atticus.mdc` in the chat. |
| Windsurf, Antigravity | `atticus: …` and mention the `sdlc-atticus` rule | Reference the rule file under `.windsurf/rules/` or `.antigravity/rules/`. |
| GitHub Copilot | `atticus: …` | Attach `.github/instructions/sdlc-atticus.instructions.md`. |
| Cline | `atticus: …` | The rule in `.clinerules/` loads with every task. |
| Aider | `/read .sdlc/skills/atticus.md`, then your request | |
| Gemini CLI, AGENTS.md agents | `atticus: …` | The instructions are in `GEMINI.md` or `AGENTS.md`. |
| Tabnine | `atticus: …` | Reference `@.sdlc/skills/atticus.md`. |

`atticus go` opens the right thing for you. For Claude Code it starts `claude "/atticus"`. For the
others it copies the right line to your clipboard and opens the editor or CLI.

---

## Platform setup: macOS, Linux, Windows

### macOS

```bash
brew install jq            # git, shasum, perl and bash 3.2 ship with macOS
curl -fsSL https://raw.githubusercontent.com/manojkvel/sdlc_central/main/get-atticus.sh | bash
exec zsh                   # reload the profile
atticus doctor
```

The hooks target bash 3.2 on purpose, so the system bash is enough.

### Linux (Debian, Ubuntu, Fedora, Arch, Alpine)

```bash
sudo apt-get install -y jq git        # Debian or Ubuntu
sudo dnf install -y jq git perl       # Fedora or RHEL
sudo pacman -S jq git                 # Arch
sudo apk add bash jq git coreutils    # Alpine: install bash, the default shell is ash
curl -fsSL https://raw.githubusercontent.com/manojkvel/sdlc_central/main/get-atticus.sh | bash
exec $SHELL && atticus doctor
```

Hashing uses `shasum` when present and `sha256sum` otherwise. Both give identical hashes, so a
repository can move between macOS and Linux. Date handling tries BSD `date -j`, then GNU `date -d`.

### Windows

Atticus is bash. On Windows you run it in one of two ways.

**Recommended: WSL2.** Keep the repository inside the Linux file system (`~/code/...`, not
`/mnt/c/...`), where hooks run faster and file modes behave.

```powershell
wsl --install -d Ubuntu      # once, in an admin PowerShell, then reboot
```

```bash
# inside Ubuntu
sudo apt-get update && sudo apt-get install -y jq git
curl -fsSL https://raw.githubusercontent.com/manojkvel/sdlc_central/main/get-atticus.sh | bash
exec bash && atticus doctor
```

Claude Code, Cursor and VS Code all work against a WSL folder: use VS Code "Remote - WSL", or run the
Claude Code CLI inside WSL. The hook commands call `bash`, so the agent must run in the same WSL
environment.

**Alternative: Git for Windows (Git Bash).**

```powershell
winget install Git.Git jqlang.jq
```

```bash
# in Git Bash
curl -fsSL https://raw.githubusercontent.com/manojkvel/sdlc_central/main/get-atticus.sh | bash
exec bash && atticus doctor
```

For PowerShell, run `atticus setup --shell pwsh` and paste the function it prints into `$PROFILE`.
`bin\atticus.cmd` also works from `cmd`.

Windows settings that matter:

- **Line endings.** Scripts must keep LF endings. Before cloning, run
  `git config --global core.autocrlf input`, or add `* text=auto eol=lf` to `.gitattributes`. The
  error `bash\r: No such file or directory` means the endings were converted.
- **Symlinks.** Without Developer Mode, Git Bash copies instead of linking. If `atticus` goes stale
  after an update, rerun `atticus setup`.
- **Claude Code on native Windows.** Hooks need `bash` on the PATH that Claude Code sees. Git Bash
  provides it.

---

## Configure your project profile

After install, these files hold the project's settings. All are plain text and committed.

| File | What to set |
| --- | --- |
| `<agent-dir>/sdlc-central.json` | `track_root` (default `.track`), `tier_default`, roles, agent. Written by the installer. Protected from agent edits. |
| `<config-dir>/config/gate-config.json` | Gate profiles per tier, risk level per gate, and `authenticated_identity_required`. Default is `false`. Set it to `true` once the decision bot is live. |
| `<config-dir>/config/profiles.yaml` | Work-type profiles: tier floor, required artifacts, required personas. Add your own. |
| `.track/stakeholders.yaml` | Who decides each gate, the SLA in hours, who it escalates to, and the named people per role. |
| `.track/baseline.json` | Your pre-Atticus numbers (lead time, deploy frequency and so on) so metrics can show change. |

The config directory is `.claude/config` for Claude Code and `.sdlc/config` for other agents.

Example `stakeholders.yaml` people block:

```yaml
people:
  product-owner: [dana@example.com]
  architect: [sam@example.com, priya@example.com]
  release-manager: [rel-managers]        # an SSO group name, checked by the decision bot
```

**Who you are.** A decision typed in the agent is recorded under `AIDLC_DECIDER` if you set it,
otherwise your `git config user.name`. That identity is *asserted*, not authenticated. For
high-risk and release gates, use the decision bot so GitHub or SSO vouches for you.

---

## Core ideas: units, tiers, profiles, risk, gates

**Unit of work.** One change with one goal: a feature, a fix, a migration. Each unit is a phase
folder `.track/phases/NN-slug/`. Exactly one phase is current at a time. Its identity is in
`unit.yaml`.

**Tier.** How much ceremony the unit needs.

| Tier | Gate profile | Typical work | Required artifacts |
| --- | --- | --- | --- |
| 1 | minimal | a small fix in one repo | `unit.md` |
| 2 | standard | a normal feature | `SPEC`, `PLAN`, `PLAN_CHECK`, `TASKS`, `VERIFICATION`, `REVIEW`, `SCORECARD` |
| 3 | strict | work across teams or repos with contracts | tier 2 plus `TECHNICAL_DESIGN` and contract evidence |

The tier comes from `unit.yaml`. If that is missing, the runner infers it: the profile sets a
floor, any contract makes it tier 3, and a small single-repo spec makes it tier 1.

**Profile.** The kind of work. It sets the tier floor and adds or removes required artifacts.

| Profile | Tier floor | What it adds |
| --- | --- | --- |
| `feature` | 2 | the standard tier 2 set |
| `bugfix`, `poc` | 1 | only `unit.md`; no technical design |
| `security` | 2 | every gate treated as security-sensitive; security reviewer persona required; technical design required |
| `infra` | 2 | plan must list permitted destructive commands and a rollback section |
| `data` | 2 | a data contract is required |
| `migration` | 2 | `migration-tracker.md` is required |

**Risk.** Each gate has a risk level: `low`, `medium`, `high`, `security-sensitive` or `release`.
Higher risk needs a stricter reply. At low risk "ok" is accepted and recorded as an approval. At
high risk the approval must include the risk you accept. At release risk it must state the scope.

**Gates.** The `aidlc/unit-of-work` pipeline has these stages and gates:

```text
source → grill → spec → [APPROVE SPEC] → risk → plan → check-plan → [APPROVE PLAN] → tasks
      → implement → verify → review → spec-conformance → scorecard → [APPROVE RELEASE] → handoff
```

Hooks stop source writes until the plan check has passed, and while the plan has lost a decision,
a task has no verify command, or the context still holds an open question.

**Grill.** Before the spec, Atticus asks you every question that is ready, in one numbered round,
each with a recommended answer. Reply only with the numbers you disagree with. It looks facts up
itself. Each answer becomes a decision `D-NNN` in `CONTEXT.md` and `decisions.md`, and every decision
must then appear in `PLAN.md` (T05). You can ask for it any time: `/atticus grill me`.

**Test first.** Every task in `TASKS.md` names its `Verify:` command (T07). The agent records the new
test failing before the change (`--red`), then passing after it. The verifier fails any task without
that red-then-green pair. At every gate in brackets the agent
stops and waits for a person.

**Personas.** Eight role prompts route each stage to a specialist: orchestrator, product
strategist, domain expert, plan checker, verifier, governance reviewer, security and standards
reviewer, and delivery manager. On Claude Code they are subagents with their own fresh context.

---

## Use cases, step by step

### A. New feature (tier 2)

In your agent:

```text
/atticus add password reset by email
```

1. Atticus opens a unit (`.track/phases/NN-password-reset-by-email/`, profile `feature`, tier 2) and
   hands it to the product strategist. It grills you in one or two rounds of questions, records your
   answers as decisions in `CONTEXT.md`, writes `SPEC.md`, then stops at the spec gate. You reply `APPROVE SPEC` or `REQUEST CHANGES: <what>` as a plain message.
2. Type `/atticus` to continue. The plan is written and the plan checker audits it. `PLAN_CHECK.md`
   must end with `## PLAN CHECK PASSED`. It stops at the plan gate for `APPROVE PLAN`.
3. `/atticus` again: tasks are written, each with a `Verify:` command. For each task the new test is
   recorded failing first (`--red`), then the code is written and the passing run recorded.
4. `/atticus prove it works`: the verifier writes the sealed `VERIFICATION.md`. Review and spec
   conformance follow.
5. `/atticus are we ready to ship`: the governance reviewer produces the sealed `SCORECARD.md`, and
   the release manager decides `APPROVE RELEASE: <scope>`.
6. `/atticus hand this over`: docs are written and the phase closes.

From a terminal, `atticus start password-reset` opens the unit the same way.

### B. Small bug fix (tier 1)

```text
/atticus login crashes when the email is empty
```

1. Atticus recognises a defect, opens a tier 1 unit (profile `bugfix`) and writes `unit.md` with
   you: the fix, the acceptance check, the files.
2. It finds the root cause, then makes the fix. Source writes are allowed because `unit.md` exists.
3. It records the proof, for example
   `atticus evidence run --task TASK-001 --kind test -- npm test -- login`, and runs the verifier.

### C. Security-sensitive change

```bash
atticus start rotate-signing-keys --profile security
```

Every gate is treated as security-sensitive. Approvals need text, for example
`APPROVE PLAN: accept 5 minute dual-key window during rotation`. The security reviewer persona
must produce `REVIEW.md` with no open CRITICAL or HIGH finding. `TECHNICAL_DESIGN.md` is required.

### D. Infrastructure change

```bash
atticus start move-queue-to-sqs --profile infra
```

`PLAN.md` must include `## Permitted destructive commands` and `## Rollback`. The command guard
blocks destructive commands such as `terraform destroy`, `rm -rf` and `kubectl delete` unless the
plan lists them (code C00 logs the permitted run). Any destructive command is blocked while a
gate is open.

### E. Data or schema change

Use `--profile data`. The unit must name a data contract. If other teams consume the data, run it
as tier 3 with the hub (use case H).

### F. Migration

Use `--profile migration`. Keep `migration-tracker.md` in the phase folder up to date. The
architect's `migration-planning` pipeline and the `migration-tracker` skill help produce it.

### G. Proof of concept

Use `--profile poc`. It works like tier 1: `unit.md` only. Do not release from a proof of concept.
Start a real unit when it graduates.

### H. Multiple teams or repositories (tier 3, hub and spoke)

One repository acts as the **hub**. It holds the workstream map, the contract registry and the
central technical design. Each team's repository is a **spoke** with its own `.track/`.

```bash
# in the hub repository
atticus init --role architect --hub
atticus contract workstream WS-001 --name Payments --repo ../payments --owner "Helen T"
atticus contract workstream WS-002 --name Checkout --repo ../checkout --owner "Ravi K"
atticus contract register C-001 --kind api --producer WS-001 --consumers WS-002 \
  --schema contracts/payments-v1.yaml --test "npm run contract:payments"
atticus contract request-approval C-001
# the architect replies: APPROVE CONTRACT: <text>
atticus contract approve C-001
```

A spoke that consumes an unapproved contract is blocked from source writes (code W09). To
proceed anyway, the owner accepts the risk:
`APPROVE WORKSTREAM CONTRACT WITH RISK: WS-002 - build against draft C-001, exclude refunds from release`.
The exclusion stays on the unit until `LIFT EXCLUSION: WS-002 - C-001 approved`. If the
producer later breaks the contract test, the contract becomes BREACHED and consumers are blocked
again. See `docs/aidlc/hub-and-spoke.md`.

### I. Adopting Atticus in an existing project

```bash
atticus init --role tech-lead
atticus migrate --dry-run          # shows what would be copied from specs/ into .track/phases/
atticus migrate                    # copies, never deletes; logs each file's hash in lineage
atticus migrate --reverse          # restores originals from lineage if you change your mind
```

Use `--from .planning` to import a tree from the reference aidlc-agent layout.

### J. Non-developer roles

| Role | What they use |
| --- | --- |
| Product owner | `idea-to-spec`, `feature-intake`, `release-signoff` pipelines. Decides the spec gate. |
| Architect | `design-to-plan`, `contract-first`. Decides the plan, technical design and contract gates. |
| QA | `release-validation` with UAT evidence (`atticus evidence run --kind uat`). |
| Release manager | `integration-release`. Decides the release gate with the sealed scorecard in front of them. |
| Scrum master, tech lead | `atticus status`, `atticus sla`, the console, and `team-health`. |

---

## Artifacts: what is created and what to commit

Commit `.track/` with the code. It is how teammates, CI, reviewers and a future you see exactly
where the work stands. The only things ignored are raw evidence log bodies.

### Project-level files (`.track/`)

| File | Written by | Purpose | Commit |
| --- | --- | --- | --- |
| `state.md` | runner, approval guard, `atticus start` | Resume block: phase, stage, open gate, next action and owner | yes |
| `human-decisions.md` | approval guard or decision bot only | One HD record per decision: who, when, gate, text, artifact hashes | yes |
| `lineage.md` | hooks, runner, tools (append-only) | Every stage change, decision, evidence run, contract and handoff event | yes |
| `guardrail-log.md` | hooks | Every block, with its code | yes |
| `requirements.md` | spec step | REQ ids across units | yes |
| `decisions.md` | plan and design steps | Design decisions (D ids) | yes |
| `risks.md` | risk step | RISK ids and who signed them | yes |
| `roadmap.md` | runner, handoff | Units done and planned | yes |
| `stakeholders.yaml` | you | Deciders, SLAs, escalation | yes |
| `baseline.json` | you | Pre-adoption metrics | yes |
| `gate-history.json` | runner, scorecard | Gate outcomes for metrics | yes |
| `runs/` | runner, usage hook | Pipeline run state, and token usage in `runs/usage/` | yes |
| `.gitignore` | init | Ignores evidence `.out`, `.err` and `.log` bodies | yes |

### Per-unit files (`.track/phases/NN-slug/`)

| File | Tier | Written by | Notes |
| --- | --- | --- | --- |
| `unit.yaml` | all | `atticus start` or the runner | id, profile, tier, repos, verify command |
| `unit.md` | 1 | you or the agent | the fix, the acceptance check, the files |
| `CONTEXT.md` | 2, 3 | source step | what the agent read, from the source graph |
| `SPEC.md` | 2, 3 | spec step | REQ and AC ids |
| `TECHNICAL_DESIGN.md` | 3, security | design step | |
| `PLAN.md` | 2, 3 | plan step | maps every AC to tasks |
| `PLAN_CHECK.md` | 2, 3 | plan checker | must end `## PLAN CHECK PASSED` |
| `TASKS.md` | 2, 3 | tasks step | TASK ids traced to ACs |
| `SUMMARY.md` | 2, 3 | implement step | must not contradict verification (X03) |
| `evidence/index.json` | all | evidence recorder | one small entry per run |
| `evidence/<TASK>/<NNN>-touched.tsv` | all | evidence recorder | files and hashes touched by a run |
| `evidence/<TASK>/<NNN>-*.out`, `.err` | all | evidence recorder | raw output. Local only, not committed. |
| `VERIFICATION.md` | all | `atticus verify` | sealed; never hand-written |
| `UAT.md`, `CONTRACT_EVIDENCE.md` | as needed | `atticus verify --mode uat` or `--mode contract` | sealed |
| `REVIEW.md` | 2, 3 | review step | findings by severity |
| `SCORECARD.md` | releases | `atticus scorecard` | sealed; ends `GOVERNANCE APPROVED` or `BLOCKED` |

**Sealed** means the first line is `<!-- generated-by: … sha256:… -->` holding a hash of the rest
of the file. A hand edit breaks the seal and is detected (H05). Hand writes are blocked (W08, C05).

### Other committed output

- `docs/aidlc/` holds the wiki, metrics and console data that you choose to publish.
- `.github/workflows/aidlc-*.yml` holds the CI workflows, if installed.

---

## Sessions: stop, resume, continue

Atticus never relies on the agent's memory. The resume block in `.track/state.md` is the single
source of truth for where work stands. The runner rewrites it after every step, so you can close
the terminal, reboot, switch agents or switch machines at any point.

```text
## AIDLC_RESUME
CURRENT_PHASE: 03-password-reset
CURRENT_STAGE: planning
BLOCKED_GATE: approve-plan
GATE_RISK: medium
GATE_REMINDED: no
NEXT_ACTION: Decide the plan gate
NEXT_ACTION_OWNER: human:architect
NEXT_ACTION_INPUTS: .track/phases/03-password-reset/PLAN.md, PLAN_CHECK.md
DONE: source, spec, approve-spec, risk, plan, check-plan
EVIDENCE: none
OPEN_RISKS: RISK-004
```

### To resume

```bash
atticus go            # opens your agent at the resume point
```

or, inside an agent that is already open, type `/atticus`. Either way Atticus reads only the resume
block and continues:

- **If a gate is open**, it shows the decision to type, such as `APPROVE PLAN` or
  `REQUEST CHANGES: …`. Type it as a plain message. The approval guard records it and unblocks the
  work.
- **If no gate is open**, it does `NEXT_ACTION` with the persona that owns it.

`atticus resume` prints the same thing in the terminal without opening the agent. A resumed session
starts small, because only the resume block is read until the next step needs more.

### Common situations

| Situation | What to do |
| --- | --- |
| You closed the terminal mid-step | `atticus go`. The half-finished step reruns from its inputs. |
| The agent stopped at a gate and you came back next day | Type the decision. Nothing else is needed. |
| You want to switch from Claude Code to Cursor | `atticus init --agent cursor`. `.track/` is shared, so the state carries over. |
| A teammate picks up your work | They pull the branch and run `atticus go`. `NEXT_ACTION_OWNER` says whose move it is. |
| You want to start something else | Finish the current unit, or tell `/atticus` to switch. The old phase stays on disk. |
| The state looks wrong | Run the consistency check below. X01 reports when `state.md` disagrees with lineage. |

```bash
bash .claude/hooks/aidlc-artifact-consistency-check/aidlc-artifact-consistency-check.sh --all
```

Agents never edit the resume block by hand. Only the runner, the approval guard and the start tool
(used by `/atticus` and `atticus start`) write it.

---

## Human decisions

Type the decision as the **first line** of your reply, exactly and in upper case:

```text
APPROVE <GATE>                     e.g. APPROVE SPEC, APPROVE PLAN, APPROVE RELEASE
APPROVE <GATE>: <text>             required at high and security-sensitive risk (the risk you accept)
                                   and at release risk (the scope you release)
APPROVE WITH RISK: <risk and excluded scope>
REQUEST CHANGES: <reason>
REQUEST VERIFICATION: <missing evidence>
DEFER                              DEFER RELEASE or REJECT RELEASE at release gates
APPROVE WORKSTREAM CONTRACT: WS-NNN
APPROVE WORKSTREAM CONTRACT WITH RISK: WS-NNN - <risk and excluded scope>
APPROVE WORKSTREAM PLAN: WS-NNN
LIFT EXCLUSION: WS-NNN - <text>
```

Each accepted decision becomes an HD record in `human-decisions.md` and a lineage line with the
hash of every artifact it approved. Vague replies ("looks good", "sure") at medium risk or above
are refused with A01, and the guard tells you the exact accepted strings. The open-gate reminder
is shown once per checkpoint, not on every message.

For authenticated decisions, use the decision bot described in
[CI and the decision bot](#ci-and-the-decision-bot).

---

## Evidence and verification

A claim such as "tests pass" counts only if a recorded run shows it.

```bash
atticus evidence run --task TASK-003 --red -- npm test -- auth            # before the change: must fail
atticus evidence run --task TASK-003 --ac AC-1,AC-2 --kind test -- npm test -- auth
atticus evidence run --task TASK-003 --kind lint -- npx eslint src/auth
atticus evidence summary              # counts, plus failing and stale runs only
atticus evidence list                 # latest run per command, one line each
atticus verify                        # writes the sealed VERIFICATION.md for the phase
atticus verify --mode uat             # UAT.md
atticus verify --mode contract        # CONTRACT_EVIDENCE.md (tier 3)
```

The rules behind the evidence:

- The recorder runs with `pipefail`. It refuses commands that hide a failing exit code, such as
  `npm test || true` and `npm test; exit 0`.
- Each run stores the exit code, output hashes and a manifest of touched files with their hashes.
- A run is **stale** when a file it covered has changed since. Only the latest run of each command
  counts.
- An acceptance criterion passes only when a fresh run covering it exits 0.
- Test first: with `red_green_required` on (the default), each task also needs a red run before its
  passing run. A red run that passes exits 3, because a test that never failed proves nothing. A task
  can be waived only with `Red: n/a - <reason>` in `TASKS.md`, and the waiver is shown in
  `VERIFICATION.md`.

---

## Handoff

Atticus hands work over through files and a named owner, never through chat history.

### Between stages and personas

Each step writes its artifact and updates `NEXT_ACTION` and `NEXT_ACTION_OWNER`, for example
`agent:aidlc-plan-checker` or `human:architect`. The next persona starts from the resume block and
the one or two artifacts it needs. On Claude Code each persona runs as a subagent with a fresh
context, so no conversation is carried over. Only the artifacts are.

### Between people

At a gate the runner prints a **checkpoint**: the gate, the risk, a short briefing, the artifacts
to read and the accepted decisions. `NEXT_ACTION_OWNER` names the role. `stakeholders.yaml` says
which people may decide and the SLA. `atticus sla`, or the scheduled CI job, flags a gate that has
waited longer than its SLA and names the escalation role.

### Between sessions and machines

Commit `.track/` and push. Whoever pulls runs `atticus resume`. See
[Sessions](#sessions-stop-resume-continue).

### Between teams

Use the hub for cross-team work: workstreams, contracts with versions and test commands, and
approval and breach states. Teams exchange contracts, not conversations. A consumer cannot build
on a draft contract without a recorded risk acceptance. See use case H.

### To operations and the next unit

The final `handoff` step writes documentation into `docs/aidlc/` and updates `roadmap.md`. Then it
closes the phase. Lineage records `handoff.*` events. The wiki keeps durable knowledge for the
next unit, so the next unit does not depend on anyone's memory.

---

## Context management and token cost

Atticus keeps the model's context small by design:

1. **Enforcement costs nothing.** Hooks, the verifier, the scorecard, traceability, metrics and
   lint are shell scripts. The model only reads their short result.
2. **Resume from the block, not the history.** A new session reads about 15 lines of
   `state.md` and then only the artifacts the next step needs.
3. **Never read growing logs whole.** `evidence/index.json`, `lineage.md` and `guardrail-log.md`
   grow over time. Agents use `atticus evidence summary`, the summary blocks of
   `VERIFICATION.md` and `SCORECARD.md`, and `grep '<phase>' .track/lineage.md | tail -20`.
4. **Small index.** Touched-file lists go in per-run manifests. `atticus evidence compact`
   moves older inline lists out. In this repository that cut one index from about 24,600 tokens
   to 1,100.
5. **Personas get fresh context.** A subagent receives its persona prompt plus the artifacts it
   needs, not the whole conversation.
6. **Short feedback.** A block message is about 60 tokens. A decision receipt is about 150. The
   open-gate reminder is shown once per checkpoint.
7. **Tier matches ceremony.** A tier 1 fix adds almost nothing.

The estimated overhead for a tier 2 unit is 10,000 to 12,000 tokens, about 8 to 12 percent of a
full pipeline run. On Claude Code the Stop hook measures real usage per session and phase into
`.track/runs/usage/`, and `atticus metrics` reports it. Details are in
`docs/aidlc/token-economics.md`.

Artifacts are written in plain, short English. We tested compressed formats such as TOON
(token-oriented object notation) and terse "caveman" prose. We use neither for durable artifacts,
because people must read and approve them.

---

## Scorecard and release

```bash
atticus scorecard                 # for the current phase; --phase NN-slug for another
```

The scorecard checks six dimensions and seals the result:

| Dimension | Passes when |
| --- | --- |
| D1 Requirements and traceability | every REQ and AC traces to tasks and evidence (T00) |
| D2 Artifact completeness | the tier and profile's required artifacts exist and are clean |
| D3 Human approval audit | every gate before release has an accepted HD record, and state agrees with lineage |
| D4 Evidence | `VERIFICATION.md` is sealed, complete and has no stale evidence |
| D5 Contracts | tier 3 only: consumed contracts are approved, and no release exclusion remains |
| D6 Security and risk | no open CRITICAL or HIGH review finding, and every open risk is signed |

`git tag`, deploy and release commands are blocked until `SCORECARD.md` is sealed and ends
`## GOVERNANCE APPROVED` (F03). Then the release manager decides `APPROVE RELEASE: <scope>`.

---

## Metrics, console and wiki

```bash
atticus bench --open                              # refresh metrics, build the console and the Measurement Bench
atticus metrics --out docs/aidlc/metrics        # DORA-style and governance metrics per squad
atticus portfolio --out docs/aidlc/console-data # this repo's status for the console
atticus console                                 # one self-contained HTML file, no backend
atticus sla                                     # gates waiting past their SLA
atticus wiki-lint                               # wiki page checks (L01 to L08)
atticus knowledge-index                         # rebuilds the wiki index
```

- **Metrics** include lead time, deployment frequency, change failure rate and time to restore,
  plus days per stage, first-pass scorecard rate and guardrail blocks. They are computed from lineage,
  gate history and evidence, and compared against `baseline.json`. Time to restore needs an
  optional `.track/incidents.json`, which the `incident-triager` skill writes.
- **Measurement Bench.** `docs/aidlc/console/bench.html`, also the Bench tab in the console. It
  compares each measured figure with the squad's own `baseline.json`: lead time, deployment
  frequency, change failure rate, rework, test first, evidence coverage, approvals, gate wait and
  tokens per unit, with charts per unit. A value model, seeded from those measurements, sizes a
  rollout. Every figure names its source file, a missing source shows a dash, and squads are never
  ranked. For a demo, `tests/fixtures/make-sample-track.py` writes a clearly marked sample track.
- **Console.** Open the HTML file from disk, a CI artifact or an internal static host. Merge many
  repositories with `atticus portfolio --merge <out> <dir> <dir> …` for a department view.
- **Wiki.** Curated knowledge in `docs/aidlc/wiki/`, maintained by the `wiki-curate` skill and
  checked by `wiki-lint`. `source-extract` builds the source graph that `CONTEXT.md` draws on.

---

## CI and the decision bot

```bash
atticus ci                 # .github/workflows/aidlc-checks.yml
atticus ci --decisions     # also .github/workflows/aidlc-decision.yml
```

**Checks workflow.** On every pull request it runs the hook integrity check, the phase quality
gate, consistency and traceability across all phases, and wiki lint. It also builds the metrics,
knowledge index and console data as a build artifact. On a schedule it runs the SLA check and a
stale-page wiki check. For advisory agents, this is the enforcement point.

**Decision bot.** A `workflow_dispatch` workflow. A decider opens the Actions tab, picks the
gate and types the decision. GitHub authenticates the actor. The bot checks the actor against
`stakeholders.yaml`, refuses a decision for a gate that is not open, records the HD, and commits.
When it works for your team:

1. Set `"authenticated_identity_required": true` in `gate-config.json`. High-risk and release
   decisions typed in the agent are then refused with A05.
2. Protect `.track/human-decisions.md` with CODEOWNERS and branch protection so only the bot
   can change it.

See `docs/aidlc/decision-bot.md`.

---

## Update and uninstall

```bash
atticus update        # pulls the latest Atticus, then refreshes this project; keeps config and .track/
atticus doctor --fix  # checks tools, PATH, hook integrity and the track root, and repairs them
atticus remove        # removes Atticus from this project; keeps .track/ and CLAUDE.md
atticus setup --undo  # removes the command and the shell-profile block from this machine
```

`atticus update --self` updates only the framework. `atticus update --project` refreshes only the
project. The hooks are checksummed at install. If anything edits them, `atticus doctor` reports it
and `--fix` restores them.

---

## Troubleshooting: block codes

Every block prints one line, `AIDLC BLOCK <hook> <code>: <reason>. Next: <what to do>`, and is
logged in `guardrail-log.md`. The most common ones:

| Code | Meaning | Fix |
| --- | --- | --- |
| W01 | Source write with no active phase | `/atticus <what you are doing>` or `atticus start <slug>` |
| W02 | Plan not checked, plan incomplete (T05 to T07), or tier 1 without `unit.md` | Finish plan-check and fix the named gap, or fill in `unit.md` |
| W03 | Source write while a gate is open | Decide the gate (`atticus resume`) |
| W04 | Write to a secret file (`.env`, keys) | Do it by hand outside the agent |
| W05 | Edit to hooks, settings or `sdlc-central.json` | Use `atticus update` or edit by hand |
| W06 | Stage does not allow source writes | Move through the pipeline to implement |
| W07, C04 | Decision log written directly | Type the decision; the guard writes it |
| W08, C05 | Hand-written evidence or scorecard | `atticus evidence run`, `verify`, `scorecard` |
| W09 | Tier 3 consumer on an unapproved contract | Approve the contract, or accept the risk |
| C01, C02 | Destructive command (while a gate is open) | List it in `PLAN.md` under permitted commands |
| C03 | Command edits hook machinery | Do not; use `atticus update` |
| H01, H02 | Secret or raw prompt wrapper in an artifact | Remove it |
| H03 | TBD or TODO in an approved artifact | Resolve it, then re-approve |
| H05 | Sealed file edited | Regenerate with the tool |
| A01 to A04 | Decision not in the exact form | Use the exact string the guard prints |
| A05 | Authenticated identity required | Decide through the decision bot |
| A06 | Decider not listed for the role | Update `stakeholders.yaml` or ask the listed person |
| T01 to T04 | Traceability gap | Map the orphan REQ, AC or task |
| T05 | A decision from the grill is not in `PLAN.md` | Say in the plan how the decision is applied |
| T06 | An open question is left in `CONTEXT.md` | `/atticus grill me` to settle it |
| T07 | A task has no `Verify:` line | Add the command that proves it, or `n/a - <reason>` |
| X01 | `state.md` disagrees with lineage | Resume through the runner; do not hand-edit state |
| X02 | Approved artifact changed after approval | `REQUEST CHANGES` and re-approve, or revert |
| X03 | Summary claims done but verification has FAIL | Fix and re-verify |
| F01 to F04 | Release claim without verification, scorecard, or fresh evidence | `atticus verify`, `atticus scorecard` |
| K01 to K03 | Contract registry problem | See `docs/aidlc/hub-and-spoke.md` |
| I02, I03 | Hook integrity failure | `atticus update` |

Other problems:

| Symptom | Cause and fix |
| --- | --- |
| `AIDLC WARN … jq not found; hook skipped` | Install jq. Until then hooks allow everything. |
| Nothing is ever blocked | No track root. Run `atticus doctor --fix`. Hooks are inert until `.track/state.md` exists. |
| `bash\r: No such file or directory` | CRLF line endings. See the Windows notes. |
| Hooks do nothing in Cursor or Copilot | Expected: those agents are advisory. Use `atticus ci`. |
| `atticus: command not found` | Run `bash ~/.atticus/bin/atticus setup`, then open a new terminal. |

Full hook reference: `docs/aidlc/hooks.md`.

---

## Known limitations

- **Tested on macOS only.** Linux and Windows support is written in (the `sha256sum` and GNU
  `date` fallbacks, the Windows launcher) but has not run in CI yet.
- **Enforcement is Claude Code only.** Other agents are advisory until their hook mechanisms are
  wired. Run CI on those projects.
- **Asserted identity by default.** Decisions typed in an agent carry the git user name. Use the
  decision bot and turn on `authenticated_identity_required` for real sign-off.
- **Hub and spoke is tested with synthetic repositories only.**
- **Token usage is measured only on Claude Code.** Other agents rely on the estimates.
- **Old installers.** The interactive `setup/install.sh` and the npm package in `package/` do not
  install Atticus. Use `atticus init`.
- **Internal names.** Files, hooks and codes keep the `aidlc-` prefix. Atticus is the product
  name and the `aidlc-*` names are its parts.

---

## Credits

Three open-source projects shaped parts of Atticus. Their ideas are used, and no text was copied:

- **Grilling** comes from `grill-me` by Matt Pocock (github.com/mattpocock/skills, MIT): ask every
  ready question in one round, each with a recommended answer, until nothing is assumed.
- **Decision coverage** comes from Get Shit Done by TÂCHES (github.com/gsd-build/get-shit-done, MIT):
  decisions from the discussion must be carried into the plan.
- **Test first** comes from superpowers by Jesse Vincent (github.com/obra/superpowers, MIT): no fix
  without a test that was seen to fail.

---

## Command reference

| Command | What it does |
| --- | --- |
| `atticus setup [--shell S] [--global] [--name N] [--undo]` | Machine setup: PATH, profile block, completion, optional global Claude Code files |
| `atticus init [--agent A] [--role R] [options]` | Install into this project and create `.track/` |
| `atticus add <role>` | Add another role |
| `atticus go [path]` | Open the agent at the resume point |
| `atticus update [--self\|--project]` | Update the framework and this project |
| `atticus doctor [--fix]` | Check and repair |
| `atticus remove` | Uninstall from this project |
| `atticus start <what> [--profile P] [--tier N] [--force]` | Open a new unit of work |
| `atticus status`, `resume` | Show the resume block and what to do next |
| `atticus evidence run\|list\|summary\|compact` | Record and inspect test, build, lint and UAT runs |
| `atticus verify [--mode verify\|uat\|contract]` | Generate sealed verification |
| `atticus scorecard [--phase P]` | Generate the sealed governance scorecard |
| `atticus contract …` | Hub commands: workstreams, contracts, approval, tests |
| `atticus bench [--open]` | Build the Measurement Bench and console from fresh metrics |
| `atticus metrics`, `portfolio`, `console`, `sla` | Measurement and reporting |
| `atticus wiki-lint`, `knowledge-index`, `integrity`, `decide` | Upkeep and the decision bot's recorder |
| `atticus ci [--decisions]`, `migrate […]`, `completion` | CI workflows, importing old specs, shell completion |

The old names `install`, `uninstall` and `link` still work.

Deeper references are in `docs/aidlc/`: `design-invariants.md`, `hooks.md`, `evidence.md`,
`governance.md`, `personas.md`, `metrics-knowledge-console.md`, `hub-and-spoke.md`,
`decision-bot.md` and `token-economics.md`.
