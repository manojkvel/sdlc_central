# License Compliance Audit — NutriKids (001)

> **Skill:** `license-compliance-audit` | **Auditor:** Vikram | **Date:** 2026-04-17 (workshop sim)
> **Triggered by:** `impl-to-release` strict profile requirement `require_license_audit: true`

## Tooling
- TS/JS deps: `license-checker --json` over the pnpm lockfile
- Python deps: `pip-licenses --format json` over the Poetry lock
- Native mobile: Expo SDK manifest (Apache-2.0 / MIT confirmed by Expo)

## Allowlist
MIT, Apache-2.0, BSD-2/3-Clause, ISC, Python-2.0, PSF-2.0, CC0-1.0, USDA Public Domain.

## Scan results

| Package set | Total | Compatible | Flagged | Notes |
|-------------|-------|-----------|---------|-------|
| `apps/web` (Next.js) | 412 | 411 | 1 | `node-forge` GPL-2.0-only — replace with `@noble/hashes` |
| `apps/mobile` (Expo) | 308 | 308 | 0 | clean |
| `apps/api` (Python) | 87 | 86 | 1 | `cryptography` 41 has known CVE — bump to ≥42.0.4 (license fine) |
| `packages/domain` | 0 (pure types) | — | — | — |
| Data sources | 1 | 1 | 0 | USDA FoodData Central — public domain |

## Findings

| ID | Severity | Action |
|----|----------|--------|
| LIC-001 | HIGH | Replace `node-forge` with `@noble/hashes` (both maintained, MIT). Used only in service worker — minor refactor. |
| LIC-002 | MED | Bump `cryptography` to 42.0.4+ (security, not license — but flagged here for visibility). |

## Verdict
**PASS WITH CONDITIONS** — LIC-001 must land before release; LIC-002 is a recommended bump.

Gate effect: `require_license_audit: true` is satisfied because the audit was run; HIGH findings still loop into `review-fix` Round 2 (already closed there — `node-forge` swap shipped).
