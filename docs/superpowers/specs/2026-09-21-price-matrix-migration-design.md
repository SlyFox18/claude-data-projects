# Price Matrix Migration — Design Spec

## 1. Problem Statement

`Price Matrix` (`RP - Parts Reports`) is the last remaining Tier 1 (dependency-ready)
report from `docs/architecture/report-migration-catalog.md`, deliberately held back
from Batch 1 (2026-09-21) because of a flagged real risk: its `Fact_Part_Transactions`
dependency was redesigned during the facts-catalog audit (Batch C, 2026-09-14) from
40+ columns down to 13, based on a real-usage audit across both consuming reports
(`Inventory Analysis`, `Price Matrix`).

**That audit's claim about Price Matrix is wrong.** It states "none of the
matrix-pricing columns are used anywhere" in either report, documented in both
`docs/architecture/lh-master-data-facts-catalog.md` and
`Build_Gold_PartTransactions.Notebook`'s own header comment. Grepping the actual DAX
measure bodies in Price Matrix's `MeasuresTable.tmdl` — not just visual-level
references, which is what that audit's methodology appears to have checked — finds 4
columns genuinely referenced by real, live measures: `EffectiveListSalVal`,
`EffectiveListMargin`, `MatrixSaleGained`, `MatrixMarginGained`, used in measures named
`Effective List Sale Value for Parts in Range`, `Effective List Margin $ for Parts in
Range`, `Matrix Sale Gained for Parts in Range`, `Matrix Margin Gained for Parts in
Range`, `Matrix Performance Summary`, `Matrix ROI Analysis`, and more — confirmed
placed on real report visuals and bookmarks (`grep` of `Price Matrix.Report`'s
`pages/`/`bookmarks/` directories), not orphaned. This is the report's actual namesake
functionality — the price-matrix analysis itself.

A 5th column, `CustomerNo`, is also referenced in DAX (a `Customer Concentration`
measure) but that measure isn't placed on any page — confirmed genuinely unused,
unlike the other 4.

This spec covers both fixing that real gap and completing Price Matrix's migration to
the DP backend, now that the gap is understood.

## 2. Scope

**In scope:**
1. Add the 4 confirmed-live columns to the Gold-layer `Fact_Part_Transactions` build.
2. Correct the wrong "not used anywhere" claim in both places it was written.
3. Migrate the Price Matrix report itself: repoint from `LH_Master_Data` to
   `DP_Presentation`, exhaustively audit real column usage across all 9 data-bearing
   tables (not just `Fact_Part_Transactions`), trim genuinely-unused columns with
   matching `Table.SelectColumns` M-query pins, fix the `DateTime.LocalNow()` bug.
4. Verify the 4 new columns against real ground truth, and verify the report-level
   repoint the same way Batch 1's reports were verified.

**Out of scope:**
- `CustomerNo` — confirmed unused, not restored.
- The other ~55 raw JD pass-through columns on the old production
  `Fact_Part_Transactions` (`TransferBranch`, `PinNo`, `BillToAcc`, `SaleTax`, etc.) —
  already confirmed unused by the original Batch C audit for this exact table, and
  nothing in this spec's own re-verification found any DAX/visual reference to them
  either. Not restored.
- `Inventory Analysis` — the other real consumer of `Fact_Part_Transactions`. It
  never references any of the 4 columns being added (confirmed in the same Batch C
  audit, which correctly identified Inventory Analysis's own 8-column usage — only
  the Price Matrix side of that audit was wrong). Adding columns it doesn't use is a
  pure no-op for it; no separate validation needed.
- Any change to `Fact_Inventory` or any of the 8 dimension tables' own Gold-layer
  build logic — all 8 already exist in `DP_Presentation` (confirmed directly via
  `fab ls` against the live lakehouse, not assumed from the catalog), this spec only
  covers Price Matrix's own TMDL-level usage of them (repoint + trim).

## 3. Backend Fix — `Build_Gold_PartTransactions.Notebook`

**File:** `fabric-workspace-docs/workspaces/DP - Presentation - Dev/Fact Tables/Inventory Analysis/Build_Gold_PartTransactions.Notebook/notebook-content.py`

Add 4 columns, computed from fields already available in the notebook's own
`Silver_InTrans` read (`SellPrice1`, `ListPrice`, `TradeType`, `SaleAmount`,
`CostAmount`, `Quantity` — the last three already present in the existing build under
those exact names). Real derivation logic, traced from the original production query
(`projects/price matrix - report/queries/fact tables/Fact_Part_Transactions.pq`,
verified line-by-line, not assumed):

| Column | Logic |
|---|---|
| `SellPrice1SaleVal` (intermediate, not persisted) | `SellPrice1 * Quantity` |
| `ListSaleVal` (intermediate, not persisted) | `ListPrice * Quantity` |
| `% Change` (intermediate, not persisted) | `(SellPrice1SaleVal - ListSaleVal) / SellPrice1SaleVal`, or `0` if `SellPrice1SaleVal` is `0` |
| `EffectiveListSalVal` | `SaleAmount` if `TransactionTradeType = "W"`, else `SaleAmount * (1 - % Change)` |
| `EffectiveListMargin` | `EffectiveListSalVal - CostAmount` |
| `MatrixSaleGained` | `SaleAmount - EffectiveListSalVal` |
| `MatrixMarginGained` | `Margin - EffectiveListMargin` |

`TransactionTradeType` is `Silver_InTrans.TradeType`, not currently read by this
notebook — needs adding to its initial `.select(...)` list. `Margin` is already
computed by the existing build.

The three intermediate values (`SellPrice1SaleVal`, `ListSaleVal`, `% Change`) are
computed inline as part of deriving `EffectiveListSalVal` but not persisted as their
own output columns — nothing in Price Matrix's real DAX/visual usage references them
(confirmed in the same grep that found the 4 real columns), matching this backend's
established "build what's proven needed" discipline.

Since `Inventory Analysis` never touches these columns, this is a pure addition with
no risk to that report — its own `Type IN ('C','I')` + 7-year-window import query
selects an explicit 8-column list that doesn't change.

## 4. Documentation Correction

Two places currently claim the matrix-pricing columns are unused everywhere — both
get corrected to document the real finding and why the original audit missed it
(visual-level scan only, not a DAX-measure-body grep — the same
`pbir`-doesn't-parse-DAX-bodies limitation already documented as a standing project
discipline elsewhere in this session):

1. `docs/architecture/lh-master-data-facts-catalog.md` — the `Fact_Part_Transactions`
   section's real-usage-audit claim.
2. `Build_Gold_PartTransactions.Notebook`'s own header comment — the "REAL USAGE
   AUDIT" block.

## 5. Report-Layer Migration

Same proven workflow as Batch 1 (`docs/superpowers/plans/2026-09-21-report-migration-batch1.md`):

1. Brian confirms Price Matrix isn't open in Desktop, publishes it as-is to `RP - Dev`
   first (preserving the `RP - Parts Reports` production copy as an untouched
   fallback, and creating a `.pbip` there per the established pattern).
2. Exhaustive real-usage audit across all 9 data-bearing tables (`Fact_Inventory`,
   `Fact_Part_Transactions`, `dim_BranchLocation`, `dim_DateTable`,
   `dim_DealerGroupCode`, `dim_Franchise`, `dim_Parts`, `dim_SLC`, `dim_Source`,
   `dim_VendorCode`) — `pbir fields list` for visual-level usage AND a full DAX-text
   grep across every measure table (`Calculator Measures`, `MeasuresTable`, and any
   table-level calculated columns) for column-level usage, the same combination that
   caught this spec's own central finding. Do not repeat the mistake of trusting a
   visual-only scan.
3. Repoint the SQL connection on every table currently pointed at `LH_Master_Data` to
   `DP_Presentation` (same connection-string swap pattern as every prior batch).
4. Trim genuinely-unused columns per the audit, with a matching `Table.SelectColumns`
   in each table's M query (the Batch 0 lesson: a TMDL-only trim doesn't survive a
   Desktop refresh).
5. Fix the `DateTime.LocalNow()` UTC-not-local bug in `Fact_Part_Transactions.tmdl`'s
   M query (`Date.AddMonths(Date.From(DateTime.LocalNow()), -13)`) using
   `DateTimeZone.SwitchZone()`, per `.claude/queries/DATA-REFRESH-TEMPLATE.pq`. Also
   check the `Data Refresh` table for the same pattern, since it's a recurring bug
   class independent of this specific report.
6. Check for the `dim_Parts`/`PartNumber` control-character issue if Price Matrix
   joins or relates on raw `PartNumber` text anywhere (most relationships here use
   `PartNumberKey`, a surrogate key, but this needs direct confirmation, not
   assumption).

## 6. Verification Plan

**Backend fix:** DuckDB ground-truth check against `EquipRDB`/`Silver_InTrans`
directly for the 4 new columns, independently recomputing the same derivation logic
for a sample of real transactions — same pattern as `dim_RepairOrder`'s verification
script (`.claude/queries/adhoc/dp-bronze-verify/verify_dim_repairorder_full_rebuild.py`).

**Report-layer migration:** post-publish refresh confirmation (matching Batch 1's
process — column-does-not-exist errors, if any, get investigated before being
dismissed), plus Brian's own visual confirmation of the matrix-pricing visuals
(`Matrix Performance Summary`, `Matrix ROI Analysis`, etc.) in Desktop against the
real, currently-live production report's output — the same three-way check
(ground-truth + Brian's own eyes) used throughout this project.

## 7. What This Spec Deliberately Does Not Cover

- `Customer Anatomy` and `Inspections` — explicitly deferred by Brian, separate work.
- Any other Tier 2/3 report migration — separate batches, not started.
- Any change to `Fact_Inventory`'s own Gold-layer build — already correct, no gap
  found for it in this investigation.
