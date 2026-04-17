# Release Notes — NutriKids v1.0.0

*Release date (planned): 2026-05-02* | *Audience: Oakwood Public School staff, parents, students*

## What's new
- **Log meals in 3 taps.** Cafeteria publishes the daily menu; students log lunch by tapping the dish.
- **Daily dashboard.** See how intake compares to age-appropriate targets for calories, protein, fibre, fruit/veg, sugar, sodium.
- **Weekly badges.** Earn "Rainbow Plate" (5 fruit/veg servings/day × 5 days) and "Steady Fuel" (consistent protein + complex-carb balance).
- **Parent weekly view.** Read-only summary of your own child, delivered every Sunday night.
- **Works offline.** Log even when cafeteria Wi-Fi drops; syncs within a minute once online.

## Privacy & compliance
- COPPA compliant — no data collection without parental consent (SSO-verified via Google Workspace).
- FERPA compliant — school controls access; data stored in US only.
- No third-party analytics, no ads, no social features.
- Delete-on-request available to any parent via `/v1/coppa/delete-request` (admin-initiated button in parent portal).

## Known limitations (v1)
- No fitness-tracker integration.
- Parents without Google accounts cannot use the parent view — workaround: staff may print weekly summary.
- Food correction requires cafeteria republish (by design — immutable logs).

## Technical highlights
- Row-level security in Postgres as the primary tenant isolation layer.
- Immutable cafeteria menu versions (audit-grade history).
- Server-authoritative timestamps (defends against clock-tampering).
- First-party observability only (OpenTelemetry + Tempo).

## Thanks
PO: Priya | Architect: Arjun | Dev: Mahesh, Karan, Anita | QA: Anita | Security: Vikram | DevOps: Pradeep | School nurse: Ms. Rao.
