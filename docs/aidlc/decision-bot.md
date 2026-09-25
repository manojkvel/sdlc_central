# Decision bot

Gate decisions typed into an agent carry an **asserted** identity: the guard records who the
session says it is. The decision bot records decisions with an **authenticated** identity, without a
server: a GitHub Actions workflow that GitHub runs as the person who triggered it.

## Install

```bash
bash /path/to/sdlc_central/setup/install-ci.sh --decisions     # .github/workflows/aidlc-decision.yml
```

Decide from the Actions tab (Run workflow) or:

```bash
gh workflow run aidlc-decision.yml -f gate=approve-release -f decision="APPROVE RELEASE: v1.4 data and API only"
```

The console's decision view links each open checkpoint to this workflow when the repository has a
GitHub remote.

## What it does (`hooks/_bin/aidlc-decide.sh`)

1. Verifies the hooks are intact (`aidlc-integrity.sh`).
2. Refuses if no gate is open, or if the open gate is not the one the person decided (`--expect-gate`), so
   a decision never lands on a different gate than the one reviewed.
3. Passes the decision string to `aidlc-human-approval-guard` with `--as <github.actor> --identity github`.
   The guard applies every rule it applies to a typed reply, plus stakeholder authorisation:
   when `stakeholders.yaml` lists `people` for the deciding role, anyone else is rejected (A06).
4. Commits the decision record, lineage, state and risk changes as `aidlc-decision-bot` and pushes.

## Making it authoritative

Once the workflow works, set `authenticated_identity_required: true` in the project's
`gate-config.json`. Then:

- high, security-sensitive and release decisions typed into an agent are rejected (A05);
- the scorecard fails D3 when any such decision carries an asserted identity.

Medium and low gates keep accepting typed decisions, so everyday flow stays in the agent.

`sso` is accepted as an identity source for other bots (for example an Azure DevOps pipeline or an
internal service that authenticates through SSO); they call `aidlc-decide.sh --identity sso`.

## Protect the decision log in git

The hooks stop agents from writing `human-decisions.md`, but a person with push access could still
edit it directly. Make the bot the only direct writer:

```text
# .github/CODEOWNERS
/.track/human-decisions.md   @your-org/aidlc-decision-reviewers
/.track/lineage.md           @your-org/aidlc-decision-reviewers
```

Require code-owner review on the default branch, and allow the workflow's token to push (or have it
open a pull request that an owner merges). The CI consistency check (X02, X04) catches records without
lineage and approved artifacts that changed afterwards.
