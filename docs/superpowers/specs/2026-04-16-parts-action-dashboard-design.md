# Parts Action Dashboard — Design Spec

**Date:** 2026-04-16
**Stakeholder:** Corp Parts Manager (South Plains Implement)
**Status:** Approved — ready for implementation planning

---

## Background

The Corp Parts Manager requested a way to surface daily action items to all ~20 branch-level parts managers across the company. The goal is to give each parts manager a clear, daily view of things at their location that need attention — without requiring them to dig through source systems or existing reports to find problems.

A secondary requirement is a roll-up view for the Corp Parts Manager and his 3 corp-level manager staff, so they can see the health of all branches at a glance.

---

## Audience

| Audience | Count | Technical Level | Current PBI Access |
|---|---|---|---|
| Corp Parts Manager | 1 | High | Yes |
| Corp-level managers (2 JD, 1 non-JD) | 3 | High | Yes |
| Branch-level parts managers | ~20 | Low | No (planned) |

Branch-level users are not technical. The design must minimize learning curve — ideally zero new concepts required to start using it.

---

## Chosen Approach

**Power BI Report with RLS + Power Automate daily email**

One Power BI report serves both audiences. Row Level Security (RLS) filters branch managers to their own location automatically. Each morning, Power Automate sends a personalized HTML email to each branch manager with their branch's current action item counts and a single button linking directly to their filtered report view.

Corp managers access the report directly — they already use Power BI and need no email nudge.

### Why This Approach
- Stays entirely within the existing Microsoft/Fabric ecosystem
- RLS handles branch filtering automatically — no manual report variants to maintain
- Email drives the daily habit without requiring branch managers to remember to check a report
- Sets branch managers up for broader Power BI adoption (which is planned company-wide)
- Extensible: adding new metrics follows the same pattern each time

### Approaches Considered and Rejected
- **Email only (HTML digest):** No drill-down capability. A count without the detail ("you have 23 negative parts") is not actionable on its own.
- **Teams notifications:** Teams adoption is inconsistent across locations. Introducing Teams alongside a new report creates two adoption problems at once.
- **Phased (email now, PBI later):** Safer short-term but Phase 2 tends to get deprioritized. Building it right the first time is preferred given the clear long-term direction.

---

## MVP Scope

Launch with three action categories. Additional categories are added later using the same pattern.

| Category | Source Data | What It Flags |
|---|---|---|
| Negative On Hand | Negative On Hand report / fact table | Parts with negative on-hand quantity at the branch |
| On Hand No Bin | Negative On Hand report / fact table | Parts with on-hand inventory but no bin location assigned |
| Open Tickets Aging | Open Parts Tickets report / fact table | Open parts orders exceeding an age threshold or carrying backorders |

### Future Categories (not in MVP)
The following were mentioned as possibilities but are deferred until requirements are confirmed with the Corp Parts Manager:

- Physical Inventory exceptions
- Any additional items identified by the Corp Parts Manager

> **Extensibility principle:** Every action category follows the same structural pattern — one KPI card, one detail table, one measure, one email metric card. Adding a new category is a repeatable, predictable unit of work that does not require redesigning the report or the email.

---

## Report Structure

### Page 1 — Branch Summary (Corp managers only, via RLS)

- Three KPI cards across the top: total counts for each action category across all branches
- A table listing all ~20 branches with their individual counts per category
- Clicking a branch row drill-throughs to Page 2 filtered to that branch
- Designed for monitoring and identifying which locations need attention

### Page 2 — Branch Action Items (All users)

- Three KPI cards: the branch's counts for each action category
- One detail section per category showing the specific items (part numbers, descriptions, quantities, order numbers, etc.)
- RLS filters this page to the user's branch automatically — branch managers see only their own data; corp managers can reach it via drill-through from Page 1
- Intentionally simple: no slicers, no navigation, no filters for the branch manager to interact with
- This is the page branch managers land on when they click the email button

---

## Row Level Security (RLS)

A mapping table — `dim_BranchUserAccess` — drives all security filtering.

| Column | Description |
|---|---|
| `UserEmail` | User's Microsoft login email (matched via `USERPRINCIPALNAME()`) |
| `BranchFilter` | Branch code, or `ALL` for corp-level users who see every branch |

Corp managers have `BranchFilter = ALL`, which bypasses the branch filter. Branch managers have their specific branch code.

**Adding a new user:** Insert a row in `dim_BranchUserAccess`. No report changes required.

**RLS roles:**
- `BranchManager` — filters to the user's branch code
- `CorpManager` — no filter (sees all branches)

---

## Daily Email

**Trigger:** Power Automate scheduled flow, 7:00 AM daily (Mon–Fri)

**Recipient logic:** Loop through all branch manager rows in `dim_BranchUserAccess`, query each branch's current counts, send one personalized email per branch manager.

**Email content:**
- Header: "Parts Action Summary" + branch name + date + manager's first name
- Three metric cards: one per action category, color-coded by urgency (red = Negative On Hand, orange = No Bin, yellow = Aging Tickets)
- All-clear state: when all counts are zero, the email shows a positive confirmation message rather than three zeros — reinforces that the email is working and that having zero issues is a good outcome
- One CTA button: "View My Action Items →" — deep link to Page 2 of the Power BI report (RLS handles branch filtering on login)
- Footer: sent time, report name, contact email

**Adding a new metric to the email:** Add one metric card to the HTML template and one query to the Power Automate flow. No structural changes to the flow itself.

---

## Data Sources

All data comes from existing Lakehouse fact tables — no new data pipelines required for the MVP.

| Category | Expected Source Table(s) |
|---|---|
| Negative On Hand | Fact table behind the existing Negative On Hand report |
| On Hand No Bin | Same — separate measure or filtered view |
| Open Tickets Aging | Fact table behind the existing Open Parts Tickets report |

Exact table names and measure definitions to be confirmed during implementation by reviewing the existing semantic models.

---

## Onboarding Plan for Branch Managers

Branch managers are new to Power BI. First-time experience must be smooth.

- The email button deep-links directly to Page 2 of the report
- On first click, the user will be prompted to log in with their Microsoft account — this should be the only friction point
- After login, they land directly on their branch's action items with no navigation required
- A short one-page "how to use" reference card should be created and distributed alongside the initial rollout
- The Corp Parts Manager or his team handles communication to branch managers about the new tool

---

## Out of Scope (MVP)

- Marking action items as resolved / acknowledgement tracking
- Mobile app or Power Apps version
- Teams notifications
- Physical Inventory integration (deferred — requirements not confirmed)
- Historical trending or week-over-week comparisons
- Automated escalation if items are not addressed

---

## Open Questions

- What is the exact age threshold for "Open Tickets Aging"? (e.g., 30 days? 14 days? Backorder only?)
- Are there additional action categories the Corp Parts Manager wants to include that have not been identified yet?
- Which specific columns from the Open Parts Tickets report are most useful to show in the detail table?
- Will the ~20 branch managers have Power BI licenses assigned before launch, or does that need to be coordinated?
