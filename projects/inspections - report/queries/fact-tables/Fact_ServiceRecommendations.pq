/*
============================================================================
FACT_SERVICERECOMMENDATIONS - PREDICTIVE SERVICE RECOMMENDATIONS
============================================================================

📋 TABLE OVERVIEW:
Purpose: For each currently-pending inspection job code, find which other
services historically get added to completed work orders carrying that same
inspection code, with frequency and average revenue — powers the
Recommendations report page's predictive upsell panel.
Grain: One row per (pending InspectionJobCode) x (co-occurring service JobCode
+ JobType) combination.
Refresh Strategy: Full refresh (small output, ~9,700 rows as of 2026-08-13).
Source Dependencies: Fact_LaborJobSummary, Fact_PendingInspections (both
Lakehouse tables in LH_Master_Data, built by their own dataflows).

🎯 BUSINESS USE CASES:
- Predictive Recommendations: given the current pending inspection queue,
  surface the services most likely to be added once each inspection
  completes (frequency %, historical average revenue).
- Same business logic the Recommendations page has always used — this
  query replaces a DAX calculated table, not the underlying logic.

🔧 WHY THIS EXISTS (moved from DAX to a dataflow, 2026-08-13):
The original implementation was a DAX calculated table in the Inspections
semantic model (GENERATE + nested CALCULATETABLE/SUMMARIZE over
Fact_LaborJobSummary, ~380K rows). DAX calculated tables cannot be
incrementally refreshed and always fully recompute on every model refresh —
confirmed via isolated single-table refresh timing in Desktop that this was
costing ~8 minutes on every nightly refresh, by far the largest remaining
contributor to the Inspections semantic model's CU cost once
Fact_WorkOrderParts got its own incremental refresh fix (see
docs/superpowers/plans/2026-08-12-inspections-report-rebuild.md, Phase 0.7).

This query reproduces the identical logic as a set-based SQL join, computed
once here (at data-refresh time, alongside the other fact tables) instead of
recomputed by the DAX engine on every single model refresh. VALIDATED
2026-08-13: prototyped and cross-checked row-for-row against the live DAX
table's output for IS-CS690 INSPECT (all values matched exactly, including
floating-point totals) before this dataflow was built.

The semantic model's `ServiceRecommendations` table keeps its existing name
and column names (InspectionJobCode, JobCode, JobType, CompletedInspections,
TimesAdded, TotalLabor) — only its partition source changes, from a DAX
`calculated` partition to a normal `m` partition reading this table via the
SQL Analytics Endpoint (same pattern as Fact_WorkOrderParts / Fact_LaborJobSummary).
This means zero changes needed to any of the ~15 measures or the one
relationship that already reference `ServiceRecommendations` by name.

🎯 LOGIC (unchanged from the original DAX, translated to SQL):
1. InspectionCodes: distinct JobCode values currently in Fact_PendingInspections
   (the "recommendations only make sense for what's pending right now" rule —
   same as the DAX version, so this table's rows still change as the pending
   queue changes, just recomputed nightly with the rest of the model instead
   of on every refresh).
2. InspectionWorkOrders: for each inspection code, the distinct historical
   work orders where that code was completed with an inspection flag set and
   an invoice number present (IsInspection = 1, InvoiceNumber IS NOT NULL).
3. CompletedInspections: count of those work orders per inspection code.
4. For every OTHER (non-inspection) service that appeared on those same work
   orders: TimesAdded = distinct work order count, TotalLabor = sum of
   InvoicedLaborAmount across all matching rows.

Frequency % and revenue projections are still computed in DAX measures
downstream (unchanged) — this table only supplies the raw counts/totals,
same as the original calculated table did.
============================================================================
*/

let
    Source = Sql.Database(
        "xcrafcusadsu3d3wi4anbgp6we-gxnyznhdptpenfw724g3o5sjzm.datawarehouse.fabric.microsoft.com",
        "LH_Master_Data"
    ),
    Query = Value.NativeQuery(
        Source,
        "
        WITH InspectionCodes AS (
            SELECT DISTINCT JobCode AS InspectionJobCode
            FROM dbo.Fact_PendingInspections
        ),
        InspectionWorkOrders AS (
            SELECT DISTINCT ic.InspectionJobCode, f.WorkOrderNumber
            FROM InspectionCodes ic
            INNER JOIN dbo.Fact_LaborJobSummary f
                ON f.JobCode = ic.InspectionJobCode
                AND f.IsInspection = 1
                AND f.InvoiceNumber IS NOT NULL
        ),
        CompletedCounts AS (
            SELECT InspectionJobCode, COUNT(DISTINCT WorkOrderNumber) AS CompletedInspections
            FROM InspectionWorkOrders
            GROUP BY InspectionJobCode
        ),
        ServiceRows AS (
            SELECT
                iwo.InspectionJobCode,
                f2.JobCode,
                f2.JobType,
                COUNT(DISTINCT iwo.WorkOrderNumber) AS TimesAdded,
                SUM(f2.InvoicedLaborAmount) AS TotalLabor
            FROM InspectionWorkOrders iwo
            INNER JOIN dbo.Fact_LaborJobSummary f2
                ON f2.WorkOrderNumber = iwo.WorkOrderNumber
                AND f2.IsInspection = 0
            GROUP BY iwo.InspectionJobCode, f2.JobCode, f2.JobType
        )
        SELECT
            sr.InspectionJobCode,
            sr.JobCode,
            sr.JobType,
            cc.CompletedInspections,
            sr.TimesAdded,
            sr.TotalLabor
        FROM ServiceRows sr
        INNER JOIN CompletedCounts cc ON cc.InspectionJobCode = sr.InspectionJobCode
        ",
        null,
        [EnableFolding = false]
    ),
    SetDataTypes = Table.TransformColumnTypes(
        Query,
        {
            {"InspectionJobCode", type text},
            {"JobCode", type text},
            {"JobType", type text},
            {"CompletedInspections", Int64.Type},
            {"TimesAdded", Int64.Type},
            {"TotalLabor", type number}
        }
    )
in
    SetDataTypes

/*
============================================================================
✅ FACT_SERVICERECOMMENDATIONS - DATAFLOW REPLACEMENT FOR DAX CALCULATED TABLE
============================================================================

Dataflow: df_Fact_ServiceRecommendations
Location: LH_Master_Data -> Dataflows -> 04 - Fact
Output: Lakehouse table dbo.Fact_ServiceRecommendations

🎯 EXPECTED RESULTS (as validated 2026-08-13):
- Row count: ~9,700 rows (22 distinct pending inspection codes as of this date
  -- will vary day to day with the pending queue)
- Refresh time: server-side join/aggregation, expect well under a minute
  (compare to the ~8 min the DAX calculated table cost on every refresh)

⚠️ AFTER THIS DATAFLOW IS BUILT AND HAS RUN SUCCESSFULLY AT LEAST ONCE:
the Inspections semantic model's `ServiceRecommendations` table needs its
partition swapped from `calculated` (DAX) to `m` (reading this new lakehouse
table), keeping the table/column names identical. See
docs/superpowers/plans/2026-08-12-inspections-report-rebuild.md, Phase 0.7
for the walkthrough. Do NOT do the model-side swap until this dataflow has a
confirmed successful run and the output table exists in the Lakehouse.
============================================================================
*/
