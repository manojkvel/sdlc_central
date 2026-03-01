---
name: security-audit
description: Security vulnerability scan of code changes or a specific module
allowed-tools: Read, Write, Grep, Glob, Bash(git diff, git log, git show, npm audit, pip audit, date)
---

# Security Audit

Perform a thorough security review of the codebase or recent changes.

## Step 1 — Scope the Audit

If `$ARGUMENTS` is provided, audit those specific files or modules.
Otherwise, audit recent changes:

- Run `git diff HEAD~1 --name-only` to identify changed files
- Prioritize files in: `auth/`, `api/`, `middleware/`, `routes/`, `models/`, `handlers/`

## Step 2 — Check Each Category

### Authentication & Authorization
- Are all endpoints protected with appropriate auth middleware?
- Is role-based access control (RBAC) enforced correctly?
- Are JWT tokens validated properly (signature, expiry, issuer)?
- Are session tokens regenerated after privilege changes?
- Is password hashing using bcrypt/argon2 (not MD5/SHA1)?

### Injection Vulnerabilities
- **SQL Injection**: All queries use parameterized statements or ORM — no string concatenation
- **NoSQL Injection**: MongoDB queries don't use `$where` or unsanitized `$regex`
- **Command Injection**: No `exec()`, `eval()`, `subprocess.shell=True` with user input
- **Template Injection**: Server-side templates don't render unsanitized user input
- Search for patterns: `exec(`, `eval(`, `subprocess.call(`, `shell=True`, `dangerouslySetInnerHTML`

### Cross-Site Scripting (XSS)
- User input is escaped before rendering in HTML
- React: no `dangerouslySetInnerHTML` with user-controlled content
- API responses set proper `Content-Type` headers
- CSP headers configured

### Cross-Site Request Forgery (CSRF)
- State-changing endpoints require CSRF tokens
- SameSite cookie attributes set appropriately
- CORS configuration is restrictive (not `*` for credentialed requests)

### Sensitive Data Exposure
- Search for hardcoded secrets: API keys, passwords, tokens in code
  - Patterns to grep: `password\s*=\s*["']`, `api_key`, `secret`, `token\s*=\s*["']`, `AWS_`, `PRIVATE_KEY`
- Secrets use environment variables, not config files committed to git
- Sensitive fields excluded from logs (`password`, `ssn`, `credit_card`)
- Error responses don't leak stack traces or internal paths in production

### Dependency Vulnerabilities
- Run `npm audit --json` for Node.js dependencies (if package.json exists)
- Run `pip audit` for Python dependencies (if requirements.txt exists)
- Flag any critical or high severity vulnerabilities

### API Security
- Rate limiting on authentication and public endpoints
- Request body size limits configured
- File upload validation (type, size, content)
- GraphQL: query depth and complexity limits (if applicable)

### Cryptography
- No use of deprecated algorithms (MD5, SHA1, DES, RC4)
- TLS enforced for external communications
- Proper random number generation (`crypto.randomBytes` / `secrets.token_bytes`)

## Step 3 — Format Output

### Risk Summary
| Severity | Count | Description |
|----------|-------|-------------|
| Critical | N     | Exploitable now, data loss or auth bypass |
| High     | N     | Significant risk, should fix before deploy |
| Medium   | N     | Should fix soon, limited exploitability |
| Low      | N     | Best practice improvement |

### Findings

For each finding:
```
[CRITICAL|HIGH|MEDIUM|LOW] <OWASP Category>
File: <path>:<line>
Issue: <what's wrong>
Impact: <what could happen if exploited>
Fix: <specific remediation with code example>
```

### Dependency Report
List any vulnerable dependencies with severity and recommended versions.

### Recommendations
Top 3 prioritized actions to improve the security posture.

## Step 4 — Save Report

Save the complete audit output to a persistent file for tracking and compliance.

1. Create the `reports/` directory if it doesn't exist: `mkdir -p reports`
2. Get today's date: `date +%Y-%m-%d` and capture as `$DATE`
3. Determine the scope label:
   - If `$ARGUMENTS` was provided, use a sanitized version (e.g., `auth-module` from `auth/`)
   - If no arguments, use `latest-diff`
4. Save the full audit to: `reports/security-audit-<scope>-<DATE>.md`
   - Include a YAML front-matter header with: `date`, `scope`, `risk_summary` (counts by severity), `critical_count`, `high_count`
5. Print the file path so the user knows where to find it

**Naming examples:**
- `reports/security-audit-latest-diff-2025-06-15.md`
- `reports/security-audit-auth-module-2025-06-15.md`
- `reports/security-audit-full-2025-06-15.md`
