# Parts Not Re-Ordered 24 Hours — Claude Context

## Report Overview
- **Business purpose:** Identifies parts that were sold (counter or invoice transaction) but not placed back on order within 24 business hours of the sale. Helps parts managers catch restocking gaps before on-hand inventory runs too low.
- **Primary users:** Parts managers, branch managers
- **Workspace:** RP - Parts Reports
- **Refresh tier:** Tier 1 — Daily by 5 AM. Also has a dedicated quick-refresh pipeline (`PartsNotReordered_QuickRefresh`) for intraday updates.
- **Status:** Production

## Semantic Model

### Fact Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `Fact_PartsNotReordered` | One row per part-branch-invoice sale | Branch, PartNumber, InvoiceNumber, SaleDate, TransDatetime, OnOrder | Filtered at source to `Type IN ("C", "I")` — counter and invoice sales only. Excludes returns and adjustments. |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_BranchLocation` | Shared Lakehouse dimension | `Fact_PartsNotReordered.Branch` → `BranchID` |
| `dim_DateTable` | Shared Lakehouse dimension | `Fact_PartsNotReordered.TransDatetime` → `Date` (used by `Business Hours Since Sale` calculated column) |
| `Data Refresh` | Calculated table | Refresh timestamp display |

### Calculated Columns on Fact Table
| Column | Logic |
|--------|-------|
| `Business Hours Since Sale` | DST-aware UTC→Central conversion of `NOW()`, then counts hours since `TransDatetime` minus weekend hours (uses `dim_DateTable[IsWeekend]`). This is a **calculated column**, not a measure — it recalculates on every report open. |
| `Hour of Sale` | `HOUR(TransDatetime)` — used for time-of-day analysis |

### Key Measures
| Measure | Description |
|---------|-------------|
| `Parts Not Reordered` | DISTINCTCOUNT of PartNumber where `Business Hours Since Sale <= 24` AND `OnOrder <= 0 or BLANK` |
| `Branches Affected` | DISTINCTCOUNT of Branch with same filter — how many branches have unreordered parts |
| `Total Qty Not Reordered` | Sum of `QtySold` for the same filtered set |
| `Times This Part Not Reordered` | COUNTROWS with ALLEXCEPT on PartNumber — how often this specific part goes unreordered (uses row context) |
| `Tooltip - Current Sales` | MAX of `Current12MoSales` — last 12 months sales units for tooltip |
| `Tooltip - Previous Sales` | MAX of `Previous12MoSales` — prior 12 months sales units for tooltip |
| `Tooltip - Sales Change` | Current - Previous sales difference |
| `Tooltip - Sales Change %` | Percentage change YoY (BLANK if no prior sales) |
| `Tooltip - Trend Arrow` | Text: "▲ Increasing", "▼ Decreasing", or "— Flat" |
| `Tooltip - Sales History HTML` | Full HTML tooltip card showing sales history with color-coded trend |
| `Parts Not On Order - Header` | HTML page header with personalized greeting |
| `Dashboard Hero Card - Parts Reorder` | HTML KPI hero card showing Parts Not Reordered, Branches Affected, Total Qty |

## Report Pages
| Page | Display Name | Purpose | Visibility |
|------|-------------|---------|------------|
| e384167396533ecc066e | Parts not on Order | Main dashboard | Visible |
| 7762a5964fc26ec403d9 | Tooltip | Hover tooltip | Hidden (tooltip) |
| f5c8ad063f1e5fae1099 | Tooltip2 | Hover tooltip | Hidden (tooltip) |
| ae192a70007b61c2e718 | Tooltip 3 | Hover tooltip | Hidden (tooltip) |

## Data Flow
```
EquipRDB (ODBC)
  └─ Parts transactions (counter + invoice sales)
                │
                ▼
  LH_Master_Data (Lakehouse)
  └─ Fact_PartsNotReordered (filtered to Type = "C" or "I")
                │
  dim_BranchLocation ──────────────────────────────────────┐
  dim_DateTable (for weekend exclusion in calc column) ────┤
                                                           ▼
                                          Parts Not Re-Ordered Report
```

## Known Issues & Gotchas

### `Business Hours Since Sale` — Calculated Column with DST Logic
This is a **calculated column** on the fact table (not a measure) that runs on every report open. It uses `NOW()` with manual DST-aware UTC→Central conversion logic:
- Uses `dim_DateTable[IsWeekend]` to subtract 24 hours per weekend day
- DST boundaries hardcoded: CDT (UTC-5) from 2nd Sunday of March 8:00 AM UTC to 1st Sunday of November 7:00 AM UTC

**Important:** Because this is a calculated column, it's computed at query time against the imported fact table data. If the fact table has stale data from a partial refresh, the business hours calculation will still run against current time, potentially showing stale parts as "within 24 hours" incorrectly.

### `Type` Filter in Partition Source
The fact table is filtered to `Type IN ("C", "I")` at the Power Query partition level:
- `"C"` = Counter sale
- `"I"` = Invoice sale
If other transaction types are ever relevant, the partition source query must be updated — this cannot be changed in DAX.

### `OnOrder` Null Handling
Measures use `OnOrder <= 0 || ISBLANK(OnOrder)` to catch parts not on order. A NULL/BLANK `OnOrder` is treated as "not on order." This is intentional — missing OnOrder data means no reorder has been recorded.

### Quick-Refresh Pipeline
This report has its own dedicated pipeline (`PartsNotReordered_QuickRefresh`) separate from the main Master Orchestrator. Check `projects/refresh-pipeline/` for details on when it runs.

### `Times This Part Not Reordered` Measure Context
Uses `ALLEXCEPT(Fact_PartsNotReordered, Fact_PartsNotReordered[PartNumber])` — this is a context-sensitive measure designed for use in a table/matrix filtered to a specific part. If used in a card or summary visual without row context, it will return total across all parts.

## Refresh Pipeline Position
- **Standard:** Phase 4 (Facts) in Master Orchestrator
- **Quick-refresh:** `PartsNotReordered_QuickRefresh` pipeline runs independently for intraday updates
- **Dependencies:** `dim_BranchLocation`, `dim_DateTable` must be fresh first

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Parts Not Re-Ordered.md`
