# Balance Sheet — Quick Assessment
*Skill: `feature-balance-sheet quick` | Role: Product Owner | Date: 2026-04-17*

## Feature
**NutriKids — A nutrition-tracking mobile/web app for students at Oakwood Public School.**

Students (ages 10–14) log what they eat at school lunch and at home, see a dashboard of how their intake compares to age-appropriate guidelines (calories, protein, fruit/veg servings, sugar), and earn weekly "Healthy Habit" badges. Parents can view their own child's weekly summary. The school cafeteria can publish the daily menu with nutrition info, so lunch logging becomes one tap.

## Benefit scoring (0–5)
| Dimension | Weight | Score | Weighted |
|---|---|---|---|
| User value (kids engage, learn habits) | 0.30 | 4 | 1.20 |
| Business value (school nutrition program alignment, grant funding) | 0.25 | 4 | 1.00 |
| Strategic alignment (school wellness initiative) | 0.20 | 5 | 1.00 |
| Platform leverage (first app on new mobile stack — reusable) | 0.15 | 3 | 0.45 |
| Risk reduction (anti-obesity public health goal) | 0.10 | 3 | 0.30 |
| **Total benefit** | | | **3.95 / 5** |

## Cost scoring (0–5)
| Dimension | Weight | Score | Weighted |
|---|---|---|---|
| Dev effort (6-week build est.) | 0.30 | 3 | 0.90 |
| Maintenance (nutrition DB keeps changing) | 0.25 | 3 | 0.75 |
| Tech debt risk (minor) | 0.20 | 2 | 0.40 |
| Operational risk (minors' PII, parental consent, COPPA) | 0.15 | 4 | 0.60 |
| Opportunity cost (blocks one sprint of backlog) | 0.10 | 3 | 0.30 |
| **Total cost** | | | **2.95 / 5** |

## Ratio
Benefit : Cost = 3.95 : 2.95 = **1.34**

## Gate evaluation
| Threshold (from `config/balance-sheet-config.json` defaults) | Value | Pass? |
|---|---|---|
| Benefit score ≥ 3.0 | 3.95 | ✓ |
| Benefit/cost ratio ≥ 1.2 | 1.34 | ✓ |
| No red-flag dimension (cost ≥ 4.5) | max cost = 4 (ops) | ✓ |

## Recommendation: **GO (with conditions)**
- Proceed to full spec and portfolio-level deep analysis.
- **Condition:** COPPA / minor-data compliance must be addressed in spec's Constraints section. Flag for `strict` gate profile post-spec.

---
*Decision gate outcome: `recommendation != NO_GO` → PASS. Pipeline continues.*
