# AIDLC Human Decisions Log (`human-decisions.md`)

The durable, auditable record of every human-in-the-loop decision, gate milestone and accepted risk.

> **Design rule**: vague approvals ("looks good", "ok", "yes", "ship it") are blocked by
> `aidlc-human-approval-guard` for medium, high, security-sensitive and release gates.
> Only the approval guard writes to this file. Agents and people never edit it by hand.

---

## 1. Project Metadata
- **Project ID:** <set me>
- **Project Name:** <set me>
- **Central Workspace Coordinator:** <set me>
- **Durable Audit Rail Reference:** `lineage.md` | `state.md`

---

## 2. Decision Log Index

| Decision ID | Date/Time (UTC) | Deciding Role | Decision / Gate Action | Status | Summary |
| :--- | :--- | :--- | :--- | :--- | :--- |

---

## 3. Detailed Decision Records

---

## 4. Blocked Vague Approval Log (Auditable Block/Failure Attempts)
Attempts rejected by `aidlc-human-approval-guard`, kept for transparency.

