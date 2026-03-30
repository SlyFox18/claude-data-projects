# Physical Inventory — Claude Context

## Report Overview
- **Business purpose:** Tracks annual physical inventory count progress throughout the year — how many bins have been counted vs. total, what's remaining, and which parts have never been counted this year. Manages the year-long physical count across all branches by scheduling parts into weekly "suggested count" windows.
- **Primary users:** Parts managers, branch managers, inventory coordinators
- **Workspace:** RP - Parts Reports
- **Refresh tier:** Tier 2 — Daily
- **Status:** Production (V2 is current; V1 archive exists; also a non-V2 current version exists)

## Semantic Model

### Fact / Primary Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `Physical Inventory` | One row per part-bin-branch | Branch, PartNumber, Bin, BinQty, OnHandQty, StocktakeDate, `Is Part Counted`, `Suggested Week` | Point-in-time snapshot of all inventory + stocktake status. From `dbo.Physical Inventory` (Lakehouse). |
| `Weeks` | One row per week of the year | `Week Number` | Helper/reference table for scheduling — used to assign parts to count windows |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_BranchLocation` | Shared Lakehouse dimension | `Physical Inventory.Branch` → `BranchID` |
| `dim_DateTable` | Shared Lakehouse dimension | No direct relationship (count tracking uses `TODAY()` not a date filter) |
| `Data Refresh` | Calculated table | Refresh timestamp display |

### Calculated Columns on `Physical Inventory`
| Column | Logic |
|--------|-------|
| `Is Part Uncounted This Year` | 1 if `StocktakeDate` is blank or from a prior year; 0 if counted this calendar year |
| `Is Bin Uncounted This Year` | 1 if no part in the same bin/branch has been counted this year |
| `Has Bin Qty` | (integer flag — presence of physical bin quantity) |

### Key Measures
| Measure | Description |
|---------|-------------|
| `Total Bins` | DISTINCTCOUNT of Bin — total bins to count |
| `Bins Counted` | Bins where at least one part has been counted this year |
| `Weeks Remaining` | `52 - WEEKNUM(TODAY()) + 1` — weeks left in the year |
| `Weeks Passed` | `WEEKNUM(TODAY())` — week number of current date |
| `Target %` | `Weeks Passed / 52` — expected completion % given elapsed time |
| `Weeks Left` | Days to Dec 31 ÷ 7, rounded up |
| `Current Year` | `YEAR(TODAY())` |

## Report Pages
| Page | Display Name | Purpose | Visibility |
|------|-------------|---------|------------|
| e384167396533ecc066e | Pysical Inventory *(typo — missing "h")* | Main dashboard — count progress, bins counted, target vs. actual | Visible |
| 5ef66f404d81bc850e62 | Not Counted | Parts/bins not yet counted this year | Hidden in view mode |

## Data Flow
```
EquipRDB (ODBC)
  └─ Physical inventory / bin location data (all branches)
                │
                ▼
  LH_Master_Data (Lakehouse)
  └─ Physical Inventory (includes StocktakeDate from count records)
  └─ Weeks (helper table — 52-week schedule)
  └─ dim_BranchLocation (shared)
                │
                ▼
            Physical Inventory Report (V2)
```

## Known Issues & Gotchas

### Two "Current" Versions
There are two semantic models in `reports/current/`:
- `Physical Inventory - V2.SemanticModel` — the active current version
- `Physical Inventory.SemanticModel` — appears to be another current copy (same tables/structure)
Only the `Physical Inventory - V2.SemanticModel` is documented here. Verify which one is deployed in production.

### Page Name Typo
The main page `displayName` is **"Pysical Inventory"** (missing the "h"). This is the internal page name only — the report tab visible to users may display differently. Do not "fix" this in the JSON without confirming it won't break bookmarks.

### `Is Part Counted` Source Column
The `Is Part Counted` column comes from the source data (`dbo.Physical Inventory`) — the physical count system sets this flag. `Is Part Uncounted This Year` is a calculated column that checks whether `StocktakeDate` falls in the current calendar year. If a part was last counted in December of the prior year, it will show as uncounted even if recently verified.

### Year-Based Count Logic
The report resets each calendar year — a part counted in December 2025 will show as "uncounted" starting January 1, 2026. This is by design for annual stocktake compliance.

### `Suggested Week` and `Weeks` Table
`Suggested Week` (0–52 integer) schedules when each part should be counted during the year. The `Weeks` reference table provides week labels/display. If a part has `Suggested Week = 0` or NULL, it may not appear on week-based schedules.

## Refresh Pipeline Position
- **Phase:** Tier 2 — Phase 5/6 (can finish after 8 AM)
- **Dependencies:** Physical Inventory source data must be refreshed; `dim_BranchLocation` (Phase 3)

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Physical Inventory.md`
