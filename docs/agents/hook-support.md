# AIDLC hook support by agent

| Agent | Level | How the hooks run |
| --- | --- | --- |
| claude-code | enforcing | `.claude/settings.json` hook entries (PreToolUse on Write/Edit/MultiEdit/NotebookEdit and Bash, PostToolUse, UserPromptSubmit, Stop) call `.claude/hooks/wrap.sh`. Exit 2 blocks the tool call or the prompt. |
| cursor, copilot, windsurf, cline, aider, gemini, antigravity, agents-md, tabnine | advisory | Scripts are installed to the agent directory's `hooks/` with a README. The pipeline runner calls the approval guard and the phase quality gate itself; nothing stops the agent from writing outside the runner. |

`install-role.sh` and `install-all.sh` print the level at install time and record it as
`hook_support_level` in `sdlc-central.json`. `--no-hooks` skips hook installation.

Advisory agents move to enforcing as their hook mechanisms are verified and wired
(Cursor and Tabnine are next). Until then, run the artifact checks in CI on every pull request:

```bash
bash <agent-dir>/hooks/aidlc-phase-quality-gate/aidlc-phase-quality-gate.sh
bash <agent-dir>/hooks/aidlc-artifact-consistency-check/aidlc-artifact-consistency-check.sh --all
```

## Personas and evidence tools

Every agent also receives the eight personas (native subagents on Claude Code, rules on Cursor,
custom agents on Copilot, markdown personas elsewhere) and the tools in `<agent-dir>/hooks/_bin/`
(evidence recorder, verifier, scorecard, metrics, wiki lint, knowledge index, portfolio, console,
integrity, SLA). The tools are installed even with `--no-hooks`.
