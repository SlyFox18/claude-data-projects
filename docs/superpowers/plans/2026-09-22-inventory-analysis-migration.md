# Inventory Analysis Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate Inventory Analysis from `LH_Master_Data` to `DP_Presentation`, consolidating its standalone `dim_Date` table onto the already-shared `dim_DateTable` instead of building a new Gold table for it.

**Architecture:** Same proven workflow as every prior report migration this project. The report is already published as-is to `RP - Dev` and confirmed closed in Desktop, so this is pure TMDL editing: exhaustive real-usage audit across all 11 real data tables, repoint each connection, trim per the audit's findings with matching `Table.SelectColumns` pins, and — for `dim_Date` specifically — repoint its `Item=` to `dim_DateTable` while keeping the model's own table name `dim_Date` unchanged (so none of its ~35 existing DAX references need touching).

**Tech Stack:** Power BI Desktop (`.pbip`/TMDL text format), `pbir` CLI, DuckDB + `delta_scan()` for verification, Fabric Git integration.

**Full design reference:** `docs/superpowers/specs/2026-09-22-inventory-analysis-datetable-consolidation-design.md` (approved — covers `dim_Date` specifically; this plan additionally covers the rest of the report, since a report can't be migrated with only one table repointed).

---

## Context You Need

All files live under `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/`. **Real connection strings:**
- Old: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data")`
- New: `Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation")`

**11 real data tables confirmed** (via direct grep of `Sql.Database`/`Item=` in every `tables/*.tmdl` file this session): `Fact_Inventory`, `Fact_Invoice_InventoryAnalysis`, `Fact_Part_Transactions`, `dim_BranchLocation`, `dim_CommodityCode`, `dim_Date`, `dim_DealerGroupCode`, `dim_Franchise`, `dim_ModuleType`, `dim_Parts`, `dim_PaymentMethod`, `dim_SLC`, `dim_Source`, `dim_VendorCode` — every `Item=` matches its real `DP_Presentation` table name exactly, no renames needed anywhere in this report (unlike Open Work Orders' `RepairOrderDetail`). The other 7 files in `tables/` (`BranchFranchiseSlicer`, `ConditionalFormatMeasures`, `Data Refresh`, `HeroCard Settings`, `MeasuresTable`, `PackageQtyMeasures`, `dim_DateFilter`) have no `Sql.Database` call at all — confirmed calculated/parameter/measure tables, not part of this migration.

**`DateTime.LocalNow()` check already done:** `Data Refresh.tmdl` already uses the correct DST-aware `UtcNow`/`UtcDT`/`LocalDT` pattern — no fix needed there. No other `DateTime.LocalNow()` instance found in any table this session (Task 1 re-confirms this at execution time).

**Raw-text relationship check already done:** `relationships.tmdl` (15 relationships, already read in full this session) has two raw-text joins — `Fact_Invoice_InventoryAnalysis.Branch`/`Fact_Part_Transactions.Branch` → `dim_BranchLocation.BranchID` — but no `PartNumber`-based raw-text relationship anywhere (both `PartNumberKey` relationships use the surrogate key), so the known `dim_Parts` control-character risk doesn't apply here.

**`Fact_Part_Transactions` real usage already confirmed this session** (same table this whole project already found a real gap in for Price Matrix — re-verify, don't just trust the old finding, but treat this as strong prior evidence): only 8 columns genuinely used — `TransactionDate`, `FranchiseKey`, `PartNumberKey`, `BranchKey`, `Branch`, `SaleAmount`, `CostAmount`, `Quantity` — matching exactly what's already in the redesigned 17-column Gold table. No gap.

**`dim_Date`'s real current file** (already read in full this session): 12 declared columns (`Date`, `Year`, `Month`, `MonthName`, `MonthShort`, `Day`, `Weekday`, `WeekdayName`, `WeekOfYear`, `Quarter`, `YearMonth`, `IsWeekend`). **Real finding not in the original design spec**: `MonthName` has `sortByColumn: Month` — since `MonthName` is a real, confirmed-used column (area-chart category axis) that needs to keep sorting in calendar order (not alphabetical), `Month` must be KEPT too, purely to support that sort — even though `Month` itself has zero direct usage. `dim_DateTable` already has a real `Month` column under that exact name, so this is free. **Real kept-column set for `dim_Date`'s M query is 4 columns, not 3: `{"Date", "Year", "MonthName", "Month"}`.**

**Real-tool boundary:** the report is already published to `RP - Dev` and confirmed not open in Desktop — Claude edits TMDL directly (Tasks 1-4). Brian's Desktop refresh/publish/visual-confirm is a separate task (Task 6) — Claude does not drive Desktop.

---

### Task 1: Exhaustive real-usage audit

**Files:** none — investigation only. Findings get documented directly in this plan before Task 3 proceeds.

- [x] **Step 1: `pbir fields list`**

```bash
export PATH="$HOME/.local/bin:$PATH"
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev"
pbir fields list "Inventory Analysis.Report"
```

- [x] **Step 2: DAX-text grep across every measure/calculated table + relationships**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition"
for tbl in Fact_Inventory Fact_Invoice_InventoryAnalysis Fact_Part_Transactions dim_BranchLocation dim_CommodityCode dim_DealerGroupCode dim_Franchise dim_ModuleType dim_Parts dim_PaymentMethod dim_SLC dim_Source dim_VendorCode; do
  echo "=== $tbl ==="
  grep -rohE "'?${tbl}'?\[[A-Za-z0-9_%]+\]" tables/*.tmdl relationships.tmdl 2>/dev/null \
    | sed -E "s/'?${tbl}'?\[([A-Za-z0-9_%]+)\]/\1/" | sort -u
done
```

- [x] **Step 3: Bookmark check**

This project has already found bookmark filters are a real, independent hidden-usage class (missed by both `pbir` and DAX-text grep on Pin Capture's `dim_DateTable.IsRolling12Months` in Batch 2a). Check whether this report has bookmarks and, if so, grep them for any column you're considering trimming:

```bash
ls "Inventory Analysis.Report/definition/bookmarks/" 2>/dev/null
grep -rn "<ColumnName>" "Inventory Analysis.Report/definition/bookmarks/" 2>/dev/null
```

- [x] **Step 4: Confirm no `DateTime.LocalNow()` beyond what's already known**

```bash
grep -rn "DateTime.LocalNow" "Inventory Analysis.SemanticModel/"
```
Expected: no live call anywhere (only the explanatory comment already in `Data Refresh.tmdl`, matching every other report's own already-fixed `Data Refresh` table).

- [x] **Step 5: Document findings**

For each of the 13 tables in Step 2's list (excluding `dim_Date`, handled separately in Task 2), record which columns are genuinely used (confident to keep) vs. genuinely unused (confident to trim). **Only trim a column if you're confident it's unused by ALL applicable checks — if ambiguous, don't trim it, note it instead.**

---

### Task 1 Findings

**Method note (applies to every table below):** "Used" was tested against five independent sources, not just the two named in Step 2: (1) `pbir fields list` output, (2) the `Table[Column]`-qualified DAX-text grep across `tables/*.tmdl` + `relationships.tmdl`, (3) `relationships.tmdl`'s `fromColumn`/`toColumn` declarations (a different TMDL syntax than DAX bracket refs — relationship key columns like `FranchiseKey`/`PartNumberKey`/`BranchKey`/etc. don't match the `Table[Column]` grep pattern at all and had to be cross-checked separately, or they'd have been falsely flagged unused), (4) the bookmark `Entity`/`Property` check, and (5) a broad whole-report/whole-model text grep for every column name that survived checks 1–4 with zero hits, to rule out cultures-file/visual-JSON usage the narrower checks could miss. A handful of broad-grep hits turned out to be false positives (auto-generated `cultures/en-US.tmdl` translation entries that exist for every column regardless of use, a `LastName` collision with an unrelated local DAX variable name in `MeasuresTable.tmdl`, and `State`/`City` matching common substrings elsewhere in the repo) — those are called out per-table below rather than left silently resolved.

**Scope decision on DAX-calculated columns:** Several tables (mainly `Fact_Inventory`, also `dim_Franchise`) have calculated (DAX `=`) columns, not just stored/M-sourced ones. This migration's established trim pattern (`dim_Date` in Task 2, `Fact_Part_Transactions` in Task 3 Step 2) only ever trims **stored** columns via `Table.SelectColumns` in the M query — calculated columns aren't part of the M source at all and removing one is a different, riskier action (deleting a TMDL column block that other calculated columns may depend on internally). All calculated columns are therefore left as-is in every table below, regardless of whether they show confirmed usage — this keeps the trim scope consistent with the rest of the plan and avoids unwinding internal calc-column dependency chains by hand.

#### `Fact_Inventory`
- **Keep (18 stored columns):** `FranchiseKey`, `PartNumberKey`, `SourceKey`, `SLCKey`, `DealerGroupKey`, `CommodityCodeKey`, `VendorCodeKey`, `BranchKey` (all 8 are relationship join keys per `relationships.tmdl` — none matched the `Table[Column]` DAX grep pattern since relationship TMDL syntax is `fromColumn: Fact_Inventory.X`, not `Fact_Inventory[X]`), `InventoryCost`, `QuantityOnHand`, `Description`, `Current12MoSales`, `DateLastRequested`, `PartNumber`, `Previous12MoSales` (direct: pbir + DAX-grep + bookmarks), `BinQty` and `Returnable` (not directly used by any measure/visual, but feed calculated columns `ExcessQtyFlag`/`InventoryStatusCategory` and `'Is Returnable'` respectively, which are kept per the calc-column scope decision above — trimming the stored column would break the calc column), `PackageQty` (confirmed via `PackageQtyMeasures` visuals).
- **Trim (7 stored columns, confident — zero references anywhere, not even inside another calculated column):** `SellPrice1`, `Cost`, `BackOrderQty`, `DateCreated`, `ListPrice`, `Current12MoDollars`, `Previous12MoDollars`. Verified each appears only in its own two-line declaration (`column X` / `sourceColumn: X`) in `Fact_Inventory.tmdl` and nowhere else in the model or report.
- **Calculated columns (11 total — left as-is, out of scope per the method note):** `InventoryCategory`, `ExcessQty`, `ExcessLevel`, `SalesCategory`, `'Is Returnable'` all show confirmed real usage (pbir and/or bookmarks — `InventoryCategory` specifically is a real hidden-usage find: it's referenced **only** inside a bookmark filter, invisible to both `pbir fields list` and the DAX-text grep, the same hidden-usage class this project already found once on Pin Capture). `ExcessQtyFlag`, `ExcessInventoryCostPerRow`, `InventoryStatusCategory`, `ExcessStockFlag`, `DeadStockFlag`, `CategoryIcon` show no confirmed usage by any check, but are calculated (not M-sourced) so are not trim candidates under this migration's pattern — ambiguous/out of scope, left untouched.

#### `Fact_Invoice_InventoryAnalysis`
- **Keep (6 columns):** `InvoiceNumber` (DAX-grep — feeds the `Invoice Count` measure), `InvoiceDate` (relationship to `dim_Date` + direct pbir `Column`), `Branch` (relationship to `dim_BranchLocation.BranchID`), `ModuleTypeKey` (relationship to `dim_ModuleType`), `PartsSaleValue` (DAX-grep + pbir measure), `PaymentMethodKey` (relationship to `dim_PaymentMethod`).
- **Trim (10 columns, confident):** `CustomerNumber`, `CompanyName`, `FirstName`, `LastName`, `PartsCostValue`, `PartsMargin`, `PartsMarginPct`, `ModifiedDate`, `ModuleType`, `PaymentMethod`. Broad grep initially flagged `LastName` (3 hits) and the others (2 hits each), but all resolved to false positives: the 2-hit pattern is always just the column's own TMDL declaration plus its auto-generated `cultures/en-US.tmdl` translation entry (present for every column regardless of use); `LastName`'s 3rd hit in `MeasuresTable.tmdl` is an unrelated local DAX variable (`VAR _LastName = MID(_Name, ...)`, part of a "Welcome Back" username-greeting measure, not a reference to this table's column). Note: `PartsCostValue`/`PartsMargin`/`PartsMarginPct` look redundant with `Fact_Part_Transactions`' `SaleAmount`/`CostAmount` — the margin measures likely compute from there instead.

#### `Fact_Part_Transactions`
- Pre-specified in Task 3 Step 2 and independently reconfirmed here: all 5 checks agree the 8 already-declared columns (`TransactionDate`, `FranchiseKey`, `PartNumberKey`, `BranchKey`, `Branch`, `SaleAmount`, `CostAmount`, `Quantity`) are exactly the used set — `TransactionDate`, `FranchiseKey`, `Branch` are additionally relationship keys (to `dim_Date`, `dim_Franchise`, `dim_BranchLocation.BranchID`) beyond their direct DAX-grep hits. The table's M query already only selects these 8 columns (a prior trim, already done) — Task 3 Step 2 is a repoint-only step for this table, not a new trim.
- **`DateTime.LocalNow()` finding (real, needs fixing in Task 3):** `Fact_Part_Transactions.tmdl` line 87 has a **live** call — `CutoffDate = Date.AddYears(Date.From(DateTime.LocalNow()), -7)` — inside the M query's rolling-7-year filter. This is a genuine instance of the known `DateTime.LocalNow()`-returns-UTC-in-service bug (see `feedback` memory + `.claude/queries/DATA-REFRESH-TEMPLATE.pq`'s DST-aware pattern), separate from `Data Refresh.tmdl`'s already-fixed, already-fine `UtcNow`/`UtcDT`/`LocalDT` pattern (confirmed at `Data Refresh.tmdl` line 38 — that occurrence is only an explanatory **comment**, not a live call). Task 3 will need to replace this `CutoffDate` calculation with a DST-aware or fixed-literal approach when it repoints this table's connection string.

#### `dim_BranchLocation`
- **Keep (4 columns):** `BranchKey` (relationship, hidden key), `Branch` (direct: pbir + bookmark), `BranchID` (relationship, to two fact tables), `LocationID` (not directly used anywhere, but `Branch` has `sortByColumn: LocationID` — trimming `LocationID` would leave that sort dangling, so it must stay, matching how `dim_Date`'s `Month` was kept solely to support `MonthName`'s sort).
- **Trim (10 columns, confident — zero hits on every check, including a broad substring grep):** `BranchType`, `BranchName`, `State`, `City`, `ServiceCapacity`, `MarketPresence`, `TerritoryCoverage`, `OperationalPriority`, `RegionalClassification`, `ServiceHours`, `DistanceFromHub`, `DataQualityScore`. Note: `State` and `City` are common words that produced 156 and 42 false-positive hits respectively in an unscoped repo-wide grep (unrelated files/words) — a table-qualified/bookmark-scoped recheck came back with zero real matches for both, so they're confident trims, not ambiguous.
- **Side finding, not a trim decision:** one visual (`pages/a68c4f7fda606ccd0a48/visuals/b1f046a1ec00e1b1246e/visual.json`) and ~26 bookmark files carry a filter with `"Entity": "dim_Branch"` / `"Property": "Branch"` — but no table named `dim_Branch` (only `dim_BranchLocation`) exists anywhere in this semantic model. This looks like a pre-existing stale/orphaned filter reference (possibly predating a table rename), unrelated to this migration and not something trimming `dim_BranchLocation`'s columns affects either way. Flagging for Brian's awareness during Task 6's visual validation, not something Task 2/3 needs to act on.

#### `dim_CommodityCode`
- **Keep (1 column):** `CommodityCodeKey` (relationship, hidden key, joins from `Fact_Inventory.CommodityCodeKey`).
- **Trim (2 columns, confident):** `CommodityCode`, `CommodityGroup` — zero hits on every check. Notable: this entire dimension contributes nothing but its join key to the report — no display attribute is used anywhere. Not treated as ambiguous since the absence is confirmed by all 5 checks, not just a gap in one.

#### `dim_DealerGroupCode`
- **Keep (2 columns, both):** `DealerGroupKey` (relationship, hidden key), `DealerGroupCode` (direct: pbir + DAX-grep + bookmark).
- **Trim:** none.

#### `dim_Franchise`
- **Keep (2 columns):** `FranchiseKey` (relationship, hidden key), `Franchise` (direct: pbir + DAX-grep + bookmark).
- **Trim (13 stored columns, confident — zero hits on every check):** `FranchiseCode`, `FranchiseDisplayName`, `FranchiseType`, `FranchiseCategory`, `MarketPosition`, `ServiceComplexity`, `FranchiseSortOrder`, `BusinessPriority`, `FranchiseStatus`, `IsActive`, `IsPrimaryBrand`, `IsAgriculturalBrand`, `IsMajorBrand`.
- **Calculated columns (2 — left as-is, out of scope):** `'Franchise Group'` and `'Franchise Display'` both reference only `dim_Franchise[Franchise]` (kept regardless) and show no confirmed usage themselves, but per the calc-column scope decision they're not trimmed.

#### `dim_ModuleType`
- **Keep (3 columns):** `ModuleTypeKey` (relationship, hidden key), `ModuleTypeDescription` (direct: pbir + DAX-grep + bookmark), `SortOrder` (not directly used, but `ModuleTypeDescription` has `sortByColumn: SortOrder` — must stay to avoid a dangling sort, same pattern as `dim_BranchLocation.LocationID` and `dim_Date`'s kept `Month`).
- **Trim (2 columns, confident):** `RecordCount`, `BusinessGrouping` — zero hits on every check.

#### `dim_Parts`
- **Keep (2 columns):** `PartNumberKey` (relationship, joins from both fact tables), `PartNumber` (direct: pbir + DAX-grep + bookmark).
- **Trim (18 columns, confident — zero hits on every check, verified individually via table-qualified grep):** `Description`, `Franchise`, `Source`, `SLC`, `DealerGroupCode`, `CommodityCode`, `VendorCode`, `QuantityOnHand`, `BackOrderQty`, `StockStatus`, `IsAvailable`, `InventoryCost`, `SellPrice1`, `ListPrice`, `Current12MoSales`, `HasRecentSales`, `ActivityStatus`, `Returnable`, `IsReturnable`, `IsHighValue`. This report uses `dim_Parts` purely as the `PartNumber` display/relationship anchor — all its denormalized attribute columns duplicate what `dim_Franchise`/`dim_Source`/`dim_SLC`/`dim_DealerGroupCode`/`dim_CommodityCode`/`dim_VendorCode` already provide via `Fact_Inventory`'s own separate keys, so they're genuinely redundant here, not just under-used.

#### `dim_PaymentMethod`
- **Keep (2 columns):** `PaymentMethodKey` (relationship, hidden key), `PaymentMethodDescription` (direct: pbir + DAX-grep + bookmark).
- **Trim (3 columns, confident):** `PaymentMethod`, `PaymentCategory`, `SortOrder`. Explicitly checked for a `sortByColumn` on `PaymentMethodDescription` pointing at this table's own `SortOrder` (since `dim_ModuleType` has an identically-named column protected by exactly this pattern) — confirmed **no** `sortByColumn` property exists anywhere in `dim_PaymentMethod.tmdl`, so `SortOrder` here is a true, unprotected trim candidate, not a false match to the `dim_ModuleType` case.

#### `dim_SLC`
- **Keep (2 columns, both):** `SLCKey` (relationship, hidden key), `SLC` (direct: pbir + DAX-grep + bookmark).
- **Trim:** none.

#### `dim_Source`
- **Keep (2 columns, both):** `SourceKey` (relationship, hidden key), `Source` (direct: pbir + DAX-grep + bookmark).
- **Trim:** none.

#### `dim_VendorCode`
- **Keep (2 columns, both):** `VendorCodeKey` (relationship, hidden key), `VendorCode` (direct: pbir + DAX-grep + bookmark).
- **Trim:** none.

#### Ambiguous columns
None of the stored/M-sourced columns landed in a genuinely ambiguous state — every candidate resolved cleanly to keep or trim once cross-checked against relationships.tmdl and a broad whole-repo grep. The only "leave as-is regardless of usage status" columns are the calculated (DAX) columns called out per-table above (`Fact_Inventory`'s `ExcessQtyFlag`/`ExcessInventoryCostPerRow`/`InventoryStatusCategory`/`ExcessStockFlag`/`DeadStockFlag`/`CategoryIcon`, `dim_Franchise`'s `'Franchise Group'`/`'Franchise Display'`) — these aren't ambiguous about usage (all show zero confirmed usage), they're out of scope for the M-query trim pattern this migration uses, by design.

#### sortByColumn dependency summary
Two tables (besides `dim_Date`, already handled in Task 2) have a `sortByColumn` property that constrains trimming:
- `dim_BranchLocation.Branch` → `sortByColumn: LocationID` — `LocationID` must be kept.
- `dim_ModuleType.ModuleTypeDescription` → `sortByColumn: SortOrder` — `SortOrder` must be kept.

No other table among the 13 has any `sortByColumn` property (confirmed via a direct grep across all 13 files).

---

### Task 2: Consolidate `dim_Date` onto `dim_DateTable`

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/dim_Date.tmdl`

- [ ] **Step 1: Remove the 8 genuinely-unused columns**

Remove these `column` blocks entirely (each is a `column Name` header line through its final `annotation` line, followed by a blank line): `MonthShort`, `Day`, `Weekday`, `WeekdayName`, `WeekOfYear`, `Quarter`, `YearMonth`, `IsWeekend`. Keep `Date`, `Year`, `MonthName` (including its `sortByColumn: Month` property and `changedProperty = SortByColumn` line, both unchanged), and `Month` (kept solely to support `MonthName`'s sort — confirmed via direct read this session, not from the original design spec).

- [ ] **Step 2: Repoint the M query and pin the column selection**

Find:
```
	partition dim_Date = m
		mode: import
		source =
				let
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
				    dbo_dim_Date = Source{[Schema="dbo",Item="dim_Date"]}[Data]
				in
				    dbo_dim_Date
```
Replace with:
```
	partition dim_Date = m
		mode: import
		source =
				let
				    // Consolidated onto the shared dim_DateTable (2026-09-22) instead of
				    // building a separate Gold-layer dim_Date table - dim_DateTable already
				    // has every column this report needs, under identical names. The model's
				    // own table stays named "dim_Date" so none of the report's existing DAX
				    // measures or relationships need to change - only this M query's source
				    // and column selection changed. Month is kept alongside Date/Year/
				    // MonthName solely to support MonthName's own sortByColumn (calendar
				    // order, not alphabetical) - it has no direct usage itself.
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
				    dbo_dim_DateTable = Source{[Schema="dbo",Item="dim_DateTable"]}[Data],
				    SelectedColumns = Table.SelectColumns(dbo_dim_DateTable, {"Date", "Year", "MonthName", "Month"})
				in
				    SelectedColumns
```

- [ ] **Step 3: Confirm no `LH_Master_Data` reference remains in this file**

```bash
grep -n "LH_Master_Data" "workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/dim_Date.tmdl"
```
Expected: no output.

- [ ] **Step 4: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/dim_Date.tmdl"
git commit -m "Consolidate Inventory Analysis's dim_Date onto dim_DateTable

Repoints to the already-shared Gold dim_DateTable instead of building
a new, separate table - per Brian's own long-standing intent to
consolidate all reports onto one date dimension. Model table name
unchanged, so no DAX/relationship changes needed. Month kept solely
to support MonthName's existing sortByColumn.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Repoint the other 10 real data tables

**Files:**
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/Fact_Inventory.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/Fact_Invoice_InventoryAnalysis.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/Fact_Part_Transactions.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/dim_BranchLocation.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/dim_CommodityCode.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/dim_DealerGroupCode.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/dim_Franchise.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/dim_ModuleType.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/dim_Parts.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/dim_PaymentMethod.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/dim_SLC.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/dim_Source.tmdl`
- Modify: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/dim_VendorCode.tmdl`

- [x] **Step 1: Repoint all 10 tables' SQL connections**

In each file, find:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com", "LH_Master_Data"),
```
Replace with:
```
				    Source = Sql.Database("xcrafcusadsu3d3wi4anbgp6we-inkp24yoeqfedgiktcbh6mwaq4.datawarehouse.fabric.microsoft.com", "DP_Presentation"),
```
No `Item=` changes in any of these 10 files — every real table name already matches exactly.

- [x] **Step 2: Trim `Fact_Part_Transactions.tmdl` to its 8 confirmed-used columns**

Keep only `TransactionDate`, `FranchiseKey`, `PartNumberKey`, `BranchKey`, `Branch`, `SaleAmount`, `CostAmount`, `Quantity`. Remove every other declared `column` block. Add a matching `Table.SelectColumns(dbo_Fact_Part_Transactions, {"TransactionDate", "FranchiseKey", "PartNumberKey", "BranchKey", "Branch", "SaleAmount", "CostAmount", "Quantity"})` step to the M query, with the `in` clause pointing at it. Check for any `sortByColumn` on a kept column pointing at a column being removed — repoint or remove it if dangling, matching the discipline already applied to `dim_Date` in Task 2.

- [x] **Step 3: Trim the other 9 tables per Task 1's findings**

For each of `Fact_Inventory`, `Fact_Invoice_InventoryAnalysis`, `dim_BranchLocation`, `dim_CommodityCode`, `dim_DealerGroupCode`, `dim_Franchise`, `dim_ModuleType`, `dim_Parts`, `dim_PaymentMethod`, `dim_SLC`, `dim_Source`, `dim_VendorCode`: if Task 1 found confident, unambiguous unused columns, remove them and add a matching `Table.SelectColumns` M-query step. Check for dangling `sortByColumn` on every trim. If Task 1's findings for a given table were ambiguous or found nothing confidently trimmable, leave that table's columns as-is (repoint only) — do not trim speculatively.

- [x] **Step 4: Confirm no `LH_Master_Data` references remain anywhere in the report**

```bash
grep -rn "LH_Master_Data" "workspaces/RP - Dev/Inventory Analysis.SemanticModel/"
```
Expected: no output.

- [x] **Step 5: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Inventory Analysis.SemanticModel/definition/tables/"*.tmdl
git commit -m "Repoint Inventory Analysis's remaining 10 data tables to DP_Presentation

Fact_Part_Transactions trimmed to its 8 confirmed-used columns,
matching the redesigned Gold table exactly. Other tables trimmed per
the Task 1 exhaustive audit where confident, left as-is where
ambiguous.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

**Execution note (2026-09-22):** Committed as `deb52e6a` on `fabric-workspace-docs`/`dev`. The commit message was expanded beyond the text above to explicitly call out the `Fact_Part_Transactions` `DateTime.LocalNow()` DST-aware fix (Task 3 Step 2), since that fix isn't mentioned in this pre-written message. Two count discrepancies surfaced between Task 1's summary counts and its own named column lists (not actual data errors — the named lists were followed exactly): `dim_BranchLocation`'s trim list names 12 columns but the summary says "10 columns"; `dim_Parts`'s trim list names 20 columns but the summary says "18 columns". Both tables' full named lists were verified individually in Task 1 and trimmed exactly as named.

---

### Task 4: Create the `.pbip`

**Files:**
- Create: `fabric-workspace-docs/workspaces/RP - Dev/Inventory Analysis.pbip`

- [x] **Step 1: Confirm the Report and SemanticModel folders exist**

```bash
ls -d "workspaces/RP - Dev/Inventory Analysis.Report" "workspaces/RP - Dev/Inventory Analysis.SemanticModel"
```

- [x] **Step 2: Create the `.pbip` file**

```json
{
  "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",
  "version": "1.0",
  "artifacts": [
    {
      "report": {
        "path": "Inventory Analysis.Report"
      }
    }
  ],
  "settings": {
    "enableAutoRecovery": true
  }
}
```

- [x] **Step 3: Commit**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git add "workspaces/RP - Dev/Inventory Analysis.pbip"
git commit -m "Add Inventory Analysis.pbip for RP - Dev

Fabric's own Git integration doesn't create this - same pattern
already used for every other report migrated in this project.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

**Execution note (2026-09-22):** Committed as `89fc828d` on `fabric-workspace-docs`/`dev`.

---

### Task 5: Push

**Files:** none.

- [x] **Step 1: Push to origin**

```bash
cd "/c/Users/bfox/Documents/Git-Projects/fabric-workspace-docs"
git push origin dev
```

**Execution note (2026-09-22):** Pushed `148df486..89fc828d` to `origin/dev` (covers the Task 2 code-quality fix, Task 1 findings doc, Task 3's repoint+trim commit, and Task 4's `.pbip`).

---

### Task 6: Brian — pull, refresh, publish, and visually confirm

**Files:** none — Brian's action.

- [ ] **Step 1: Pull into `RP - Dev`**

Sync/update to pick up Tasks 2-4's commits.

- [ ] **Step 2: Open Inventory Analysis from `RP - Dev` in Desktop and refresh**

Watch for "column does not exist" errors — if any appear, that means Task 1's audit missed a real usage; report back for investigation rather than assuming the trim is wrong.

- [ ] **Step 3: Visually confirm real output**

Against the real, currently-live `RP - Parts Reports` production version — specifically the date-based visuals (YoY comparisons, the 5-year trend measure, the area-chart category axis using `MonthName`) to confirm the `dim_DateTable` consolidation didn't change any date-based behavior.

- [ ] **Step 4: Publish to `RP - Dev`, then Source control → Commit**

- [ ] **Step 5: Report back**

Once confirmed, Claude runs the final post-publish verification (Task 7).

---

### Task 7: Post-publish verification and catalog update

**Files:**
- Modify: `data-projects/docs/architecture/report-migration-catalog.md`

- [ ] **Step 1: DuckDB row-count check**

```python
import duckdb
con = duckdb.connect()
con.execute("INSTALL delta; LOAD delta; INSTALL azure; LOAD azure;")
con.execute("CREATE SECRET (TYPE azure, PROVIDER credential_chain, CHAIN 'cli');")
base = "abfss://73fd5443-240e-410a-990a-98827f32c087@onelake.dfs.fabric.microsoft.com/966efc8a-16f9-423b-aa43-e368fcd8fb91/Tables"

tables = [
    "Fact_Inventory", "Fact_Invoice_InventoryAnalysis", "Fact_Part_Transactions",
    "dim_BranchLocation", "dim_CommodityCode", "dim_DateTable", "dim_DealerGroupCode",
    "dim_Franchise", "dim_ModuleType", "dim_Parts", "dim_PaymentMethod", "dim_SLC",
    "dim_Source", "dim_VendorCode",
]
for t in sorted(set(tables)):
    try:
        n = con.execute(f"SELECT COUNT(*) FROM delta_scan('{base}/{t}')").fetchone()[0]
        print(f"  OK  {t}: {n:,} rows")
    except Exception as e:
        print(f"  MISSING/ERROR  {t}: {e}")
```

- [ ] **Step 2: Update the catalog doc**

Mark Inventory Analysis complete in `docs/architecture/report-migration-catalog.md`'s Batch 2 section, matching the same completion-note pattern already used for Batch 2a, noting the `dim_Date`-consolidation approach superseded the originally-planned new-table build.

---

## Self-Review Notes

**Spec coverage:** The design spec's scope (section 2: repoint `dim_Date`'s M query to `dim_DateTable`, keep model table name, trim to real usage) → Task 2, fully specified. The spec's explicit non-goals (no new Gold table, no change to `dim_DateTable` itself) → respected throughout; Task 2 never touches `dim_DateTable`'s own Gold-layer build. This plan's own addition beyond the spec's narrow scope (repointing the other 10 tables, since a report can't be migrated with only one table done) is covered by Tasks 1 and 3.

**Placeholder scan:** Task 1's findings feed Task 3 Step 3's trim decisions — a real sequential dependency (the audit must run first), not a placeholder. Task 2 and Task 3 Step 2 (`Fact_Part_Transactions`) are both fully specified with no dependency on Task 1, since both were already exhaustively investigated this session.

**Type consistency:** The `dim_Date` kept-column set (`Date`, `Year`, `MonthName`, `Month`) is consistent between the Context section, Task 2 Step 1 (TMDL column removal), and Task 2 Step 2 (M-query `Table.SelectColumns`). The `Fact_Part_Transactions` 8-column set is consistent between the Context section and Task 3 Step 2.
