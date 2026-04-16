# Security Audit — Tool Reference

This document explains every external tool used by the `security-audit` and `security-audit-deep` skills, why each was chosen over alternatives, and what it catches that simpler tools miss.

## Skill vs. Tool Matrix

| Tool | Skill | Install |
|---|---|---|
| `semgrep` | both | `pip install semgrep` |
| `gitleaks` | both | `brew install gitleaks` |
| `trufflehog` | both | `brew install trufflehog` |
| `npm audit` / `pip-audit` | both | bundled with npm / `pip install pip-audit` |
| `govulncheck` / `cargo audit` / `bundle-audit` | both | lang-specific |
| `bandit` / `gosec` / `brakeman` | deep | lang-specific SAST |
| `trivy` | deep | `brew install aquasecurity/trivy/trivy` |
| `grype` | deep | `brew install anchore/grype/grype` |
| `syft` | deep | `brew install anchore/syft/syft` |
| `tfsec` / `checkov` / `kubesec` | deep | `brew install tfsec`; `pip install checkov`; `brew install kubesec` |
| `testssl.sh` / `nmap` | deep (TLS check) | `brew install testssl nmap` |

---

## SAST — Code-level Vulnerability Scanners

### `semgrep` — both skills

**What**: Lightweight AST-based pattern matcher with taint tracking. Runs against 30+ languages. The `p/owasp-top-ten` ruleset maps directly to what the skill reports.

**Why chosen**: The core engine that makes this whole skill credible. Grep finds `eval(` strings — semgrep understands that `eval(req.body.code)` is tainted user input flowing into a sink. It's the one upgrade that eliminates most false positives in the fast skill.

**Why not CodeQL**: CodeQL is more powerful but requires a build step, a database, and GitHub infra. Semgrep runs in seconds on source files, no build needed. CodeQL is the right choice for GitHub Advanced Security, but overkill for a per-PR skill.

### `bandit` — deep, Python only

**What**: Python-AST SAST written by the OpenStack security team. Knows Python-specific sinks: `pickle.loads`, `yaml.load`, `subprocess(shell=True)`, `assert` statements in production code, Flask `debug=True`.

**Why chosen**: Semgrep's Python rules are good but Bandit is the reference implementation for Python. Historically catches more Python-specific issues with fewer false positives because it parses the full Python grammar.

### `gosec` — deep, Go only

**What**: Go SAST that walks the Go AST. Catches Go-specific issues: `math/rand` used for crypto, hardcoded TLS `InsecureSkipVerify: true`, file permissions wider than 0600, SQL string concatenation through `fmt.Sprintf`.

**Why chosen**: Semgrep lacks deep Go semantics (type resolution, interface satisfaction). Gosec understands Go's type system, so it can reason about what's actually an `io.Reader` vs. an `http.Request`.

### `brakeman` — deep, Ruby on Rails only

**What**: Rails-specific SAST. Understands the framework's conventions — mass assignment via `params.permit`, strong params bypass, ActiveRecord injection via `where(user_input)`, unsafe `render` of arbitrary templates.

**Why chosen**: Rails security is framework-shaped. A generic tool can't know that `User.find_by_sql(params[:q])` is exploitable in the same way Brakeman does. If the repo has no Rails, it's skipped.

---

## Secret Scanning

### `gitleaks` — both skills

**What**: Go-based scanner with 100+ built-in regex rules for common secret formats (AWS, GitHub, Slack, Stripe, OpenAI, etc.). Scans the full git history — including deleted commits — by default.

**Why chosen**: **Secrets in deleted commits are still exploitable** — once pushed, anyone can recover them from git reflog or GitHub's commit API. File-based grep misses this entire attack surface. Gitleaks is fast, hash-indexed, and produces SARIF output.

### `trufflehog` — both, fallback

**What**: Similar to gitleaks but with a killer feature: **verification**. It doesn't just match a pattern like `AKIA[0-9A-Z]{16}` — for recognized services, it actually calls the API to confirm the key is live.

**Why chosen as fallback**: Live verification eliminates false positives (expired keys, test fixtures). It's slower than gitleaks due to the API calls, so gitleaks runs first; trufflehog is the second pass when available.

**Why not `git-secrets`**: AWS Labs' `git-secrets` only has AWS patterns built in and requires manual pattern registration. Gitleaks + trufflehog ship with a comprehensive rule library.

---

## Dependency Vulnerability Scanning (SCA)

### `npm audit` — both, Node.js

**What**: Bundled with npm. Hits the npm advisory database, reports CVEs in your `package-lock.json` with severity and fixed versions.

**Why chosen**: Zero install, authoritative source for npm ecosystem. `yarn audit` covers the yarn variant. Both fail in monorepo / workspace edge cases, but they're the baseline.

### `pip-audit` — both, Python

**What**: PyPA's official tool. Checks `requirements.txt` / installed packages against the PyPI Advisory Database and OSV.

**Why chosen over `safety`**: Safety (PyUp.io) was the old default but now requires a paid license for commercial use. `pip-audit` is Apache 2.0, maintained by the Python Packaging Authority itself, and uses the same OSV data that GitHub and Google use.

### `govulncheck` — both, Go

**What**: Google's official Go vulnerability checker. Unique feature: it doesn't just tell you "package X has CVE-Y" — it uses Go's call graph to tell you whether your code **actually calls the vulnerable function**. Massively reduces noise.

**Why chosen**: Reachability analysis is rare in SCA tools and dramatically improves signal. A CVE in an imported library you don't use → not flagged. Same vulnerability in code your handler calls → flagged.

### `cargo audit` — both, Rust

**What**: Rust Secure Code WG's tool. Checks `Cargo.lock` against the RustSec Advisory Database.

**Why chosen**: The canonical Rust tool, runs in the Rust toolchain, accepted as the standard by the Rust ecosystem.

### `bundle-audit` — both, Ruby

**What**: Checks `Gemfile.lock` against the Ruby Advisory DB.

**Why chosen**: Canonical Ruby SCA. `bundler-audit` is maintained and integrates with Bundler natively.

### `mvn org.owasp:dependency-check` — deep, Java/Maven

**What**: OWASP Dependency-Check scans Java dependencies against the NVD.

**Why deep only**: Slow (downloads NVD data) and Maven-specific — overkill for per-PR unless the repo is Java-heavy.

---

## Container Image Scanning

### `trivy` — deep

**What**: Aqua Security's scanner. Analyzes built OCI images layer-by-layer — OS packages (apt/apk/yum), language deps inside the image, misconfigurations (USER root, exposed secrets in ENV), and license issues. Outputs SARIF.

**Why chosen**: **This is what Dockerfile grep misses.** A Dockerfile saying `FROM node:18` looks clean, but the built image ships with 200+ OS packages any of which may have unpatched CVEs. Trivy scans what actually ships to prod, not what the Dockerfile *says*. Also the fastest, most comprehensive OSS option — now the CNCF-adopted standard.

### `grype` — deep

**What**: Anchore's image scanner. Similar scope to Trivy but uses a different vulnerability database (Anchore's feed vs. Trivy's combined sources).

**Why both**: Running both catches CVEs that one database has but the other doesn't. Not strictly necessary — either alone gives ~90% coverage. Listed because `grype` + `syft` are a paired workflow and you often get them together.

### `syft` — deep

**What**: SBOM (Software Bill of Materials) generator from Anchore. Enumerates every component in a project or container image and outputs standardized formats: CycloneDX, SPDX, or Syft JSON.

**Why chosen**: **SBOM is a compliance requirement, not just a nice-to-have.**

- **US Executive Order 14028** requires SBOMs for software sold to the federal government
- **EU Cyber Resilience Act** (CRA) mandates SBOMs for products in the EU market by 2027
- **FDA** requires SBOMs for medical devices

Syft is CNCF-adopted, handles every major ecosystem, and produces formats (CycloneDX, SPDX) that compliance auditors accept.

---

## Infrastructure-as-Code (IaC) Scanning

### `tfsec` — deep, Terraform

**What**: Terraform-focused static analysis. 200+ rules for AWS/Azure/GCP: S3 bucket public ACLs, unencrypted EBS volumes, IAM policies with `*` resource, security groups opening 0.0.0.0/0 to SSH.

**Why chosen over alternatives**: Terraform-native — understands HCL variable resolution, module inputs, and resource references. Generic YAML scanners can't resolve that `bucket_name = var.bucket` is pointing at a problematic config.

**Note**: tfsec is now part of Aqua's Trivy — `trivy config` can replace it. Listed separately because many teams have `tfsec` workflows already in CI.

### `checkov` — deep, multi-IaC

**What**: Bridgecrew (now Palo Alto Prisma) tool. Covers Terraform, CloudFormation, Kubernetes manifests, Dockerfile, ARM templates, Helm charts, serverless frameworks — all in one tool.

**Why chosen**: Broadest IaC coverage of any OSS tool. If you have a mixed IaC stack (Terraform + K8s + CloudFormation), checkov replaces 3–4 separate scanners. 1000+ built-in policies.

**Why both checkov and tfsec**: Different rule databases, different bias (tfsec is stricter on AWS, checkov is broader). Running both catches more.

### `kubesec` — deep, Kubernetes only

**What**: Pod/Deployment manifest scorer. Flags pods running as root, missing `readOnlyRootFilesystem`, excessive capabilities (`CAP_SYS_ADMIN`), hostNetwork/hostPID access, missing NetworkPolicies.

**Why chosen**: Kubernetes-specific nuance that generic YAML linters miss. Checkov overlaps, but kubesec produces a cleaner per-manifest score (0–100) that's easy to gate on.

---

## Network / TLS Testing (Live)

### `testssl.sh` — deep, runtime TLS check

**What**: 1,000-line bash script that probes an HTTPS endpoint for protocol support (TLS 1.0/1.1 deprecated), cipher suites (RC4, 3DES, CBC-SHA1 weak), certificate issues, OCSP stapling, HSTS strength, known attacks (BEAST, POODLE, LUCKY13, Heartbleed).

**Why chosen**: The most comprehensive OSS TLS scanner. Single binary, zero dependencies. Catches config errors that `curl -v` would miss — like a server that claims TLS 1.3 support but silently falls back to 1.0.

### `nmap` — deep, fallback for TLS

**What**: General-purpose network scanner with an `ssl-enum-ciphers` NSE script that grades cipher suites A–F.

**Why chosen as fallback**: nmap is almost universally installed in ops environments, even where `testssl.sh` isn't. Coverage is thinner but the critical-tier issues (no TLS 1.2, weak ciphers) still surface.

---

## Vulnerability Database Freshness

A scan is only as good as the data behind it. Stale vuln databases produce silent false-cleans — a report showing "no critical issues" when the data is months old is worse than no report. This section covers which tools use a DB, which DB, and how to keep them fresh.

### Tools that use a vuln DB (vs. bundled rules)

Only the SCA (dependency) and container scanners consult a vuln database. SAST and IaC tools use pattern rules bundled into the tool binary — "staleness" there means "the tool version is old", not "the DB is old".

| Tool | DB source | Update model |
|---|---|---|
| `npm audit` | GitHub Advisory DB (GHSA) | Live query every run — always fresh |
| `pip-audit` | PyPI Advisory DB + OSV.dev | Live query every run |
| `govulncheck` | Go Vulnerability DB (`vuln.go.dev`) | Live query every run |
| `cargo audit` | RustSec Advisory DB (git repo) | Auto `git pull` unless `--no-fetch` |
| `bundler-audit` | Ruby Advisory DB (git repo) | **Manual** — needs `bundle-audit update` |
| `mvn dependency-check` | NVD + Sonatype OSS Index | Downloads NVD feeds; cached 4 hours |
| `trivy` | Aggregated (NVD + GHSA + Red Hat + Debian + Alpine + OSV) | Auto-updates on every run unless `--skip-db-update` |
| `grype` | Anchore Feed (NVD + GHSA + vendor advisories) | Auto-updates on every run unless `--no-db-auto-update` |

### Why NVD alone is a bad idea in 2025

NIST paused enrichment of new CVEs in Feb 2024 due to a contract/funding issue. By mid-2024 ~17,000 CVEs were unanalyzed — no CVSS, no CWE, no CPE matches. The backlog is still being worked through.

Practical impact:
- A brand-new CVE published this week may have **no NVD metadata** yet
- Tools relying solely on NVD see "no data" and skip flagging
- Tools that aggregate GHSA + OSV + vendor feeds catch it because those sources enrich independently

This is why Trivy, Grype, `npm audit`, and `pip-audit` all pull from multiple sources. **OSV.dev (Google) and GHSA (GitHub) are now faster and more complete than NVD for open-source CVEs.** The one tool here that still treats NVD as primary is Maven OWASP dep-check — which is part of why it's slow and sometimes stale.

### Checking DB age manually

```bash
# Trivy — DB build date on disk
trivy image --download-db-only
ls -la ~/Library/Caches/trivy/db/trivy.db   # macOS
ls -la ~/.cache/trivy/db/trivy.db           # Linux

# Grype — explicit status command
grype db status
# Output includes: Built: 2025-04-15T06:00:00Z

# cargo audit — advisory-db is a git repo
(cd ~/.cargo/advisory-db && git log -1 --format=%ci)

# bundler-audit — same pattern
(cd ~/.local/share/ruby-advisory-db && git log -1 --format=%ci)

# Maven dep-check — NVD cache metadata
cat ~/.m2/repository/org/owasp/dependency-check-data/*/nvdLastUpdated.properties
```

### Enforcing freshness in CI — three patterns

**1. Let tools auto-update (default for most).** Trivy, Grype, `npm audit`, `pip-audit`, `govulncheck`, and `cargo audit` all update automatically on each invocation. Do NOT use flags like `--skip-db-update` / `--no-fetch` / `--offline` in CI — they exist for air-gapped environments only.

**2. Force a refresh before the scan.**

```yaml
- name: Refresh vuln databases
  run: |
    trivy image --download-db-only
    grype db update
    bundle-audit update    # if Ruby present
    mvn org.owasp:dependency-check-maven:update-only
```

**3. Staleness gate** — fail the pipeline if any DB is older than a threshold (e.g., 7 days). Catches cases where the runner was sandboxed or an update silently failed:

```bash
BUILT=$(grype db status | grep "Built:" | awk '{print $2}')
AGE_DAYS=$(( ($(date +%s) - $(date -d "$BUILT" +%s)) / 86400 ))
[ "$AGE_DAYS" -gt 7 ] && { echo "Grype DB is $AGE_DAYS days old — refresh failed"; exit 1; }
```

### Built into `security-audit-deep`

The deep skill runs a pre-flight DB freshness check at the top of Step 2 (`Pre-Flight: Verify Scanner DB Freshness`). It:

- Refreshes Trivy and Grype DBs
- Measures the on-disk age of each offline DB (Trivy, Grype, cargo advisory-db, ruby-advisory-db)
- Writes a "Scanner DB Status" table to `.audit/db-status.md`
- **Aborts the scan** if any DB is >7 days old, recording `gate_result: FAILED` and `failure_reason: stale_scanner_db`

The fast skill does not run this check — CI runners typically refresh their caches out-of-band, and a false-clean on a per-PR scan is caught by the next deep scan anyway.

### Token-cost rationale

The freshness check itself is ~500–1,000 tokens per deep run — ~0.5% overhead on an 80K–200K deep scan. But on the failure path it's negative-cost: aborting pre-flight saves the ~100K tokens the downstream scanners would have burned producing a degraded report. Stale-DB failures are loud and fast, not silent and expensive.

### Rate limits to know about

- **NVD**: unauthenticated, ~5 requests per 30 seconds. `dependency-check` can hit this on large repos. Get a free NVD API key from `nvd.nist.gov` and pass via `--nvdApiKey`.
- **OSV.dev**: no auth; generous limits. The free-tier workhorse.
- **GHSA**: GitHub GraphQL API; authenticated requests get 5,000/hour.

---

## The Meta-Pattern Behind These Choices

Four principles drove the tool selection:

1. **OSS + widely adopted.** No tool here requires a commercial license. Each has thousands of GitHub stars and active maintenance. Avoid anything that could become a commercial gate.

2. **Machine-readable output** (SARIF or JSON). Every tool in the deep skill outputs SARIF so findings can merge into `.audit/findings.sarif` and feed GitHub Advanced Security / SIEM unchanged.

3. **Graceful degradation.** Every invocation uses `|| echo "unavailable"` — the skill works without any of them (falls back to grep), works better with some, works best with all. No hard dependency.

4. **Scope-appropriate.** Fast skill tools install via `brew`/`pip` in seconds and run in seconds. Deep skill tools can be heavier (testssl.sh is slow; Maven dep-check downloads NVD). Matching tool weight to use case keeps per-PR latency low.

---

## Quick Install — All Tools

macOS / Homebrew:
```bash
# Fast skill tools
brew install semgrep gitleaks trufflehog
pip install pip-audit

# Deep skill — additional tools
brew install aquasecurity/trivy/trivy
brew install anchore/grype/grype
brew install anchore/syft/syft
brew install tfsec kubesec testssl nmap
pip install checkov bandit

# Go / Ruby / Rust ecosystem (if applicable)
go install golang.org/x/vuln/cmd/govulncheck@latest
gem install bundler-audit brakeman
cargo install cargo-audit
```

Linux equivalents use each tool's documented install method (apt/yum/curl installers from the project's GitHub release page).

---

## See Also

- [`skills/security-audit/prompt.md`](../skills/security-audit/prompt.md) — fast skill source
- [`skills/security-audit-deep/prompt.md`](../skills/security-audit-deep/prompt.md) — deep skill source
- [`skill-reference.md`](./skill-reference.md) — full skill catalog
