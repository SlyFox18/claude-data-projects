# Inspections Report Migration — Design

**Date:** 2026-09-25
**Status:** Design approved by Brian. Awaiting spec review.
**Report:** `fabric-workspace-docs/workspaces/RP - Dev/Inspections.{Report,SemanticModel}`. It is currently on LH_Master_Data. There is no `.pbip` yet.
**Target:** DP_Presentation (`DP - Presentation - Dev`)
**Related:** `docs/architecture/report-migration-catalog.md`, `docs/architecture/dp-refresh-pipeline-assessment.md`

## Goal

Repoint Inspections from LH_Master_Data to DP_Presentation, keeping parity with production. The only exceptions are two production bugs that the new build deliberately fixes, listed under Decisions. At the same time, correct the structural problems the audit found: the duplicated code lists, the missing VACUUM, the Feb-29 crash, and the untrimmed tables.

## Decisions (Brian, 2026-09-24/25)

1. **Include NULL-ModifiedDate labor punches.** Production's raw WKMECHWK filter (`ModifiedDate >= 2023`) silently drops punch rows whose ModifiedDate is NULL. These are real hours: about 15.5K in 2023, 15.9K in 2024, 4.2K in 2025 and 0 in 2026. As a result production under-counts `ActualHoursWorked` by about 10% for 2023–24. The new build includes these rows, and this is documented as a production bug fixed.
2. **2023+ scope, matching production.** The build keeps `Silver_WkOthSub` rows with `ModifiedDate >= 2023-01-01`, which reproduces production's 387,174 job rows exactly. Headers (`Silver_WkRoFile`) and punches (`Silver_WkMechWk`) are scoped **through the in-scope jobs**, not filtered on their own dates.
3. **Inspection code list stays at the 113 codes service defined.** Unlisted variants (`IS INSPECTION`, `/BASKET VIP INSPECT`, `VEHICLE INSPECT`) are not added; together they are 25 in-scope rows, and service has already cleaned up its codes. `TRIM(JobCode)` is applied before matching as a guard. It was verified to change **0 rows** in scope.
4. **The codes move to a single git-tracked lookup.** A new notebook, `Build_Gold_InspectionJobCodes`, holds the 113 codes inline and writes `lookup_InspectionJobCodes`. This replaces the three hard-coded copies in the LaborJobSummary, WorkOrderParts and PendingInspections notebooks.
5. **Gold fact tables are trimmed to used columns.** Each keeps the columns the report uses plus any column a downstream notebook reads. The shared dims are not trimmed in Gold; they are trimmed at the report layer with `Table.SelectColumns`.

## Build chain

```
Staging:  df_RepairOrderDetail_Raw (Dataflow Gen2, ODBC) → RepairOrderDetail
Silver:   Silver_WkOthSub, Silver_WkRoFile, Silver_WkMechWk,
          Silver_TechnicianPunchedDetail, Silver_InTrans
Gold w1:  Build_Gold_InspectionJobCodes      → lookup_InspectionJobCodes        (NEW)
Gold w2:  Build_Gold_LaborJobSummary          → Fact_LaborJobSummary
          Build_Gold_WorkOrderParts           → Fact_WorkOrderParts
          Build_Gold_PendingInspections       → Fact_PendingInspections
Gold w3:  Build_Gold_ServiceRecommendations   → Fact_ServiceRecommendations
            (reads Fact_LaborJobSummary + Fact_PendingInspections)
Shared dims (already exist): dim_Parts, dim_DateTable, dim_CustomerList, dim_BranchLocation
```

All 5 Gold notebooks are registered in `deploy/dp_backend_scope.json`, and in its deployed copy, with a new `wave` field (1/2/3). Today's pipeline ignores that field; it records the ordering for the pipeline redesign. Schedules are paused, so validation runs the chain **manually, level by level**.

## Notebook changes

Every notebook gets the same hygiene: `spark.sql.session.timeZone = UTC`, and after each `mode("overwrite")` write, `retentionDurationCheck` disabled followed by `VACUUM ... RETAIN 0 HOURS`.

| Notebook | Changes |
|---|---|
| `Build_Gold_InspectionJobCodes` (new, `Fact Tables/Inspections/`) | 113 codes inline, one column `JobCode`. Asserts `count == 113` and `countDistinct == 113` before writing. |
| `Build_Gold_LaborJobSummary` | Decision 1 and Decision 2 scope. Inspection flag becomes `TRIM(JobCode)` joined to the lookup. Output trimmed (see below). |
| `Build_Gold_WorkOrderParts` | Decision 2 scope. Lookup join. The 3-year cutoff's `.replace(year=year-3)`, which crashes on Feb 29, is replaced with `add_months(..., -36)`. Output trimmed. |
| `Build_Gold_PendingInspections` | Lookup join (TRIM). Output trimmed. |
| `Build_Gold_ServiceRecommendations` | Hygiene only. Logic unchanged. |

Before building, the three wave-2 notebooks assert that `lookup_InspectionJobCodes` exists and has 113 rows. If it doesn't, they fail loudly rather than silently producing zero inspections.

### Trimmed output columns (from the column-usage audit)

The audit used six methods: DAX in measures and calculated columns, relationships, `pbir fields list`, bookmarks, raw visual JSON, and sortByColumn.

- **Fact_LaborJobSummary:** `JobCode, JobType, InvoiceNumber, BranchCode, WorkOrderNumber, InvoicedLaborAmount, IsInspection, ActualHoursWorked, WorkOrderCreationDate`. ServiceRecommendations reads `WorkOrderNumber, JobCode, JobType, InvoicedLaborAmount`, which are all already in this list.
- **Fact_WorkOrderParts:** `TransactionDate, PartNumber, Quantity, SaleValue, Franchise, BranchCode, Description, CustomerNumber, InvoiceNumber`
- **Fact_PendingInspections:** `BranchCode, WorkOrderNumber, JobCode, CreationDate, LastLaborPunch, DaysSinceCreation, HoursWorked, IsInspection`. ServiceRecommendations reads `JobCode, WorkOrderNumber`, which are both in this list.
- **Fact_ServiceRecommendations:** unchanged (6 columns). `JobType` is unused by the report but is part of the grain, so it stays.

Because nothing uses `InvoiceDate` anymore, trimming removes the earlier TIMESTAMP-vs-DATE `InvoiceDate` issue entirely.

The implementation re-checks each list against the notebooks' own downstream reads before it trims anything.

## Report layer

Claude makes these edits **while the report is closed in Desktop**. Claude confirms Desktop is closed before editing and again before pushing.

1. Create `workspaces/RP - Dev/Inspections.pbip` first, then commit it.
2. Repoint the 8 LH_Master_Data partitions to `Sql.Database("...inkp24yoeqfedgiktcbh6mwaq4...", "DP_Presentation")`. ServiceRecommendations reads `Fact_ServiceRecommendations`.
3. Facts: remove the trimmed columns from the TMDL.
4. Dims: add `Table.SelectColumns` for the used columns only, and remove the others from the TMDL. The used columns are:
   - `dim_BranchLocation`: Branch, BranchID, BranchName, LocationID
   - `dim_CustomerList`: CustomerNumber, PrimaryName
   - `dim_DateTable`: DateKey, Date, MonthYear, SortableMonthYear
   - `dim_Parts`: PartNumber, Description, Franchise, SellPrice1
5. **Restore `dim_DateTable.IsRolling12Months`** as a DAX calculated column, keeping its existing lineageTag. It is used by 2 visuals and 6 bookmarks, and DP's date table doesn't have it. The DAX is the same as Pin Capture and First Pass Fill:
   ```
   VAR RefDate = MAX('Data Refresh'[Date])
   VAR StartOfRollingPeriod = EOMONTH(RefDate, -12) + 1
   VAR EndOfRollingPeriod = EOMONTH(RefDate, 0)
   RETURN dim_DateTable[Date] >= StartOfRollingPeriod && dim_DateTable[Date] <= EndOfRollingPeriod
   ```
6. The report's calculated columns stay as they are: `WorkOrderCreationDateKey`, `IsPendingInspection`, `BranchName`, `CreationMonthYear`, `CreationMonthSort`, `InspectionCategory`, `TransactionDateKey` and `HoursWorked_Clean`. `Inspection Goals` stays on Excel and `Data Refresh` stays as is. `ValidInvoiceNumbers` depends on LJS `InvoiceNumber` and `IsInspection`, both of which are kept.

Brian then pulls, opens the `.pbip`, refreshes, validates, publishes to RP - Dev, and commits through Fabric Git.

## Validation

**Before Brian opens Desktop:** a DuckDB parity check of DP against LH_Master_Data, month by month from 2023-01. Both sides are bounded to the same freshness cutoff. The check covers:
- inspection count by branch and month
- `ActualHoursWorked`
- `InvoicedLaborAmount`
- parts `SaleValue` and `Quantity`
- pending inspection count
- ServiceRecommendations row count

Only these differences are acceptable:
- NULL-ModifiedDate hours now included (Decision 1), about +10% hours in 2023–24
- the 14 InTrans invoices recovered from production's late-commit watermark gap, in WorkOrderParts
- snapshot timing, in PendingInspections and anything current-month

**Any other difference stops the work and goes to Brian**; nothing gets patched around it.

**After publish:**
- no `LH_Master_Data` left in the model TMDL
- the `IsRolling12Months` lineageTag is unchanged
- a whole-project `git status` (the pbir bookmark-filter side effect)
- key page totals match the production Inspections report
- catalog and memory updated

## Carried forward unchanged (flagged, not fixed)

- Pending-inspection hours are summed per work order across all jobs on the punch branch, and the total repeats on each inspection row.
- The backend `IsPending` column was always False in production. It is unused and is dropped by the trim. The report uses the report-layer `IsPendingInspection`.

## Out of scope

- The DP pipeline redesign and bulk registration (see the assessment doc)
- Customer Anatomy (next report, which will get the same `IsRolling12Months` treatment)
- Promotion to Sandbox and Prod
