# Pilot plan and kill criteria

The pilot decides whether Atticus continues. The criteria below are fixed **before** it starts and
signed off by the sponsor, the two squad leads and the platform lead. They are not changed during the
pilot. See `docs/aidlc/roadmap-enterprise.md` for the milestones the pilot depends on (M4, and M5 for a
non-GitHub squad).

## Shape

- Two squads for six weeks. At least one works on GitLab or Azure Repos.
- Weeks −2 to 0: baseline from the git host and tracker APIs; Atticus CI runs in shadow mode (reports,
  not required).
- Weeks 1–2: advisory. Weeks 3–6: enforcing.
- Week 3: mid-point review. Stop early if more than 15% of blocks are upheld as false.

## What is measured, and how

| Measure | Source |
| --- | --- |
| Overhead minutes per unit | opt-in `cli.invoked` durations; Atticus CI job time; pushes made after a gate failure; a weekly one-question estimate per developer |
| False-block rate | every block is a `guardrail.fired` event or a failed `atticus/*` check; `atticus dispute <event> "<reason>"` records a dispute; disputes are triaged weekly and upheld ones count as false; admin bypasses of required checks come from the host audit log |
| Read time before approval | first engagement to approval per reviewer, with comment and thread counts; the rubber-stamp flag is read time below 0.2 × expected (words ÷ 250 per minute) with no comments |
| Sentiment | a weekly pulse, 1 to 5: helped quality, slowed me down, would keep; exit interviews |
| Outcomes | proving-test rate on code units; escaped defects on auto-approved units (from sampling and incidents); DORA against the baseline |

## Kill criteria (assessed at week 6; any one triggers stop or rework)

1. Median overhead above 30 minutes per medium-risk unit, or above 10 minutes per low-risk unit.
2. False blocks above 5% of all blocks, or above 1 per developer per week.
3. Median lead time more than 20% worse than baseline with no measurable defect reduction.
4. "Would keep" below 3.0 out of 5, or fewer than half the developers would continue.
5. Rubber-stamp rate above 50% on medium- and high-risk gates.
6. Required checks bypassed more than 3 times per squad per week.

**Continue** needs all six to pass, and a proving-test rate of at least 70% on code units.

## Sign-off

| Role | Name | Date |
| --- | --- | --- |
| Sponsor | Project owner (approved in the working session) | 2026-09-27 |
| Squad lead (squad 1) | To be named when the pilot squads are chosen | |
| Squad lead (squad 2) | To be named when the pilot squads are chosen | |
| Platform lead | To be named | |

The kill criteria above are fixed as of the sponsor sign-off. Squad and platform leads confirm them when
they are named; they do not change them.
