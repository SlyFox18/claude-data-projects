# Parts Action Dashboard

## Purpose
Daily action item dashboard for branch-level parts managers and corp-level parts staff.

## Audience
- Corp managers (4): see all branches — RLS role: CorpManager
- Branch managers (~20): see own branch only — RLS role: BranchManager

## Source Tables (LH_Master_Data)
- Fact_NegativeOnHand_OnHandNoBin — branch key: Branch (verify exact format — may be BranchID with sub-branch suffixes)
- Fact_Parts_Open_Tickets — branch key: Location (LocationID format e.g. "01")
- dim_BranchUserAccess — RLS mapping (UserEmail → BranchCode or ALL)
- dim_BranchLocation — branch names and metadata

## RLS
RLS filters on dim_BranchLocation[Branch] (LocationID). Model relationships propagate
the filter to both fact tables, covering all sub-branches (I/S/C/B suffixes) automatically.
dim_BranchUserAccess maps USERPRINCIPALNAME() to a BranchCode (LocationID format).
BranchCode = 'ALL' bypasses branch filter (corp managers).

## Confirmed Locations (22)
| LocationID | Name |
|---|---|
| 01 | Seminole |
| 02 | Tornillo |
| 03 | Denver City |
| 04 | Las Cruces / Mesquite (verify — two entries share BranchCode 4) |
| 05 | Deming |
| 06 | San Angelo |
| 07 | Ballinger |
| 08 | Big Spring |
| 11 | Brownfield |
| 12 | O'Donnell |
| 13 | Lamesa |
| 14 | Littlefield |
| 15 | Levelland |
| 16 | Morton |
| 17 | Tahoka |
| 91 | Lorenzo |
| 92 | Slaton |
| 93 | Lubbock |
| 94 | Crosbyton |
| 95 | Abernathy |
| 96 | Snyder |
| 97 | Colorado City |

## Aging Threshold
Open Tickets flagged when Days_Open >= 30 OR #_On_Back_Order > 0.
Confirm threshold with Corp Parts Manager before go-live.
DAX constant: _AgingThresholdDays = 30 (in [Open Tickets Aging Count] and [Is Aging Ticket] measures).

## Extensibility
Each action category = 1 KPI card + 1 detail table + 1 measure + 1 email card.
To add a new category: add the source table, write 1 measure, add visuals to both pages,
add one card to the Power Automate email template.

## Spec
docs/superpowers/specs/2026-04-16-parts-action-dashboard-design.md

## Plan
docs/superpowers/plans/2026-04-16-parts-action-dashboard.md
