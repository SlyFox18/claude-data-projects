# Pin Capture — Claude Context

## Report Overview
- **Business purpose:** Tracks whether parts transactions (invoices and work orders) have a PIN (equipment serial/product identification number) recorded against them. Measures PIN capture rate by branch, salesperson, and franchise — and correlates PIN capture with sales margin.
- **Primary users:** Parts managers, branch managers, operations
- **Workspace:** RP - Parts Reports
- **Refresh tier:** Tier 2 — Daily
- **Status:** Production

## Semantic Model

### Fact Tables
| Table | Grain | Key Fields | Notes |
|-------|-------|------------|-------|
| `Fact_PinTransactions` | One row per parts transaction line (invoice + work order) | RONumber, Branch, TransDatetime, PartNumber, PinNo, Notation, Type, Invoice_Type | **Reads directly from `InTrans_Incremental` in the semantic model partition query** — not a pre-built Lakehouse fact table. Filters to last 24 months rolling. |

### Dimensions
| Table | Source | Key Relationship |
|-------|--------|-----------------|
| `dim_BranchLocation` | Shared Lakehouse dimension | `Branch` → `BranchID` |
| `dim_DateTable` | Shared Lakehouse dimension | `TransDatetime` → `Date` |
| `dim_Parts` | Shared Lakehouse dimension | `PartNumber` → `PartNumber` |
| `dim_CustomerList` | Shared Lakehouse dimension | Not directly related (CustomerNo column exists on fact but no relationship defined) |
| `PinFilterOptions` | Local reference table | Filter/slicer options for PIN-related views |
| `Data Refresh` | Calculated table | Refresh timestamp display |

### Calculated Columns on `Fact_PinTransactions`
| Column | Logic |
|--------|-------|
| `Has Pin` | TRUE if `PinNo` is non-blank/non-zero OR `Notation` is non-blank/non-zero |
| `Pin Identifier` | `PinNo` if present, otherwise `Notation` — unified pin reference |
| `Pin Source` | "PinNo", "Notation", "Both", or "No Pin" — where the PIN came from |
| `Invoice Has Pin Flag` | "Yes"/"No" — whether any line on the invoice has a PIN (ALLEXCEPT on RONumber) |
| `Unique Pins Per Invoice` | DISTINCTCOUNT of `Pin Identifier` per invoice (ALLEXCEPT on RONumber) |
| `Line Item Margin %` | `Margin / SaleValue` per line |
| `Line Item Status Icon` | Emoji rating combining PIN presence + margin: 💎 (pin + ≥25%), ✅ (pin + ≥15%), 🟡 (pin + ≥10%), 🟠 (pin + <10%), ⚪ (no pin + ok), ⚠️ (no pin + low margin) |

### Key Measures
| Measure | Description |
|---------|-------------|
| `Total Transactions` | DISTINCTCOUNT of RONumber |
| `Transactions with Pins` | DISTINCTCOUNT of RONumber where any line has `Has Pin = TRUE` |
| `% Transactions with Pin` | Transactions with Pins / Total Transactions |
| `Total Sales` | Sum of SaleValue |
| `Total Cost` | Sum of CostValue |
| `Total Margin` | Sum of Margin |
| `Sale with Pin` | Sales from invoices that have at least one PIN captured |
| `Cost with Pin` | Costs from pin-captured invoices |
| `MoM Change` | Capture-rate change vs. a comparison period that auto-switches based on the selected date range — see "Prior Period Comparison Logic" below. Drives both hero card KPI tiles. |
| `Branch MoM Change` | Per-branch capture-rate change vs. **always the previous calendar month** (`PREVIOUSMONTH`), regardless of what date range is selected. Drives the Branch Summary table's "Chg vs Last Mo." column — intentionally a different basis than `MoM Change`. |

## Report Pages
| Page | Display Name | Purpose | Visibility |
|------|-------------|---------|------------|
| e384167396533ecc066e | Overview | Main dashboard — PIN capture rate KPIs and breakdown | Visible |
| 1ba9729e724ba0adcc67 | Branch Summary | Branch-level capture rates | Hidden in view mode |
| ef73b4029c16257bda4b | Transaction Detail | Transaction-level detail view | Hidden in view mode |
| 80f2328a9847644f9d58 | Transaction Drill Through | Drillthrough from summary to individual transactions | Hidden (drillthrough) |

## Data Flow
```
EquipRDB (ODBC)
  └─ InTrans_Incremental (raw parts transactions table)
  └─ wkothsub (work order sub-table for WO/Invoice classification)
                │
                ▼ (inline Power Query in semantic model partition)
  Fact_PinTransactions (built at query time, not a Lakehouse table)
                │
  dim_BranchLocation, dim_DateTable, dim_Parts (shared dims) ────┐
                                                                  ▼
                                                    Pin Capture Report
```

## Known Issues & Gotchas

### Direct `InTrans_Incremental` Read (Not a Lakehouse Fact Table)
Unlike most reports, `Fact_PinTransactions` is NOT a pre-built Lakehouse table. The semantic model partition query reads directly from `InTrans_Incremental` and performs an inline left join with `wkothsub` at import time. This means:
- **Performance:** The partition runs the full join on every refresh of the semantic model — no pre-built fact to optimize against
- **Incremental dependency:** If `InTrans_Incremental` refresh fails, this report gets stale data
- **Rolling window:** The partition applies a 24-month rolling date filter as early as possible for performance

### `wkothsub` Join for Invoice_Type
The partition left-joins `wkothsub` (distinct `InvoiceNumber|Branch` combinations only — deduplicated from ~103K to ~38K rows) to classify each transaction as "Work Order" or "Invoice". This join runs at import time inside the partition source.

### `CustomerNo` — No Relationship
`CustomerNo` column exists on the fact table but `dim_CustomerList` has no defined relationship to it. The `CustomerNo` here is the AR customer number, not the `AccountNumber` used by `dim_CustomerList`. These may not match without a custom join.

### `PinNo` vs. `Notation` Both Hold PIN
A "pin" can be captured in either the `PinNo` field or the `Notation` field. The `Has Pin` calculated column checks both. When reporting captures, use `Pin Identifier` (which coalesces to the non-null value) rather than `PinNo` alone.

### Duplicate Removal in Partition
The partition includes `Table.Distinct` deduplication on 7 columns. This may silently drop records if two line items have identical timestamp, RO, part, branch, qty, and values — a rare but possible condition.

### Prior Period Comparison Logic (`[MoM Change]`)
The `[MoM Change]` measure (used by both hero card KPI tiles — Overview and Branch Summary) auto-detects what kind of range is selected and picks the comparison period accordingly:

| Selected range | Comparison period |
|---|---|
| Full single calendar month | Previous calendar month (`PREVIOUSMONTH`) |
| Full calendar quarter | Previous quarter (`PREVIOUSQUARTER`) |
| YTD (Jan 1 → any date, same year) | Same YTD range, one year earlier (`SAMEPERIODLASTYEAR`) |
| Custom range > 100 days, not YTD | Same date range shifted back exactly 1 year (`DATEADD -1 YEAR`) |
| Custom range ≤ 100 days | Same date range shifted back 1 month (`DATEADD -1 MONTH`) |

Both hero card measures (`Branch Performance - Hero Card`, `Page 1 - Overview Hero Card`) independently compute a `PriorStart`/`PriorEnd` date pair that mirrors these same branches, and label the tile with the literal comparison dates (e.g. "vs Jan 01–Jul 07, 2025") instead of a category name. **If `[MoM Change]`'s branch logic changes, the `PriorStart`/`PriorEnd` SWITCH blocks in both hero card measures must be updated to match, or the label will silently show the wrong comparison dates.**

Fixed 2026-07-07: previously the Branch Summary hero card only special-cased full-month selections and defaulted everything else (quarters, YTD, custom ranges) to the literal string "Prior Period" — never actually telling the user what it was comparing to. The Overview hero card had category labels ("vs Prior YTD", "vs Prior Quarter") that were more informative but still didn't show actual dates. Both now show literal comparison date ranges. See [[project_pin_capture_prior_period_wording]].

### PIN Accuracy — Presence-Only, Not Validated (investigated 2026-07-22)

The report only measures whether a PIN was *captured* (`Has Pin` = PinNo or Notation non-blank) — it has never validated whether the captured value is actually correct. A Parts team member raised this directly: does the report tell us capture *accuracy*, not just capture *rate*?

Investigated feasibility ad hoc — see `.claude/queries/adhoc/pin-accuracy-check/README.md` for full methodology, branch-level results, and a concrete path to production if this gets built into the report. Headline finding: matching captured `PinNo` (normalized) against the combined pool of known equipment PINs (`WKVEHFL.VIN` + `vhstock.VIN`, both already in the Lakehouse — the "VIN" columns are legacy naming for genuine John Deere Product ID Numbers) is feasible with no new dataflow, using the existing `LOOKUPVALUE`-on-lookup-table pattern already used for `lookup_UniqueCustomers_Invoice`. End-to-end match rate across the network: ~52% (or ~83% if scored only against PINs that resolve to a known machine — the two framings tell different stories and need a deliberate choice, not a default). Branch-level accuracy varies widely (Big Spring 24%, Tahoka 73%). Status: findings delivered to Brian, pending Ben's decision on whether to build this into the report.

## Refresh Pipeline Position
- **Phase:** Phase 5/6 — Tier 2, depends on `InTrans_Incremental` being fresh (Phase 2)
- **Dependencies:** `InTrans_Incremental`, `dim_BranchLocation`, `dim_DateTable`, `dim_Parts`

## Documentation Status
- In-repo docs: ✅ CLAUDE.md | ✅ PROJECT-SUMMARY.md
- Obsidian stakeholder docs: ✅ Complete — `Data Projects/Reports/Pin Capture.md`
