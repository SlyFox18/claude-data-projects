/*
============================================================================
DIM_PARTDEMANDS — ROLLING PART DEMAND BY BRANCH
============================================================================

PURPOSE:
Pre-aggregated demand lookup table. One row per Branch/PartNumber/Franchise
showing how many customer invoice transactions occurred in the rolling window.
Intended to replace ad-hoc use of jdis_Part_Information pi_sales_request_XX
buckets, which are approximate pre-aggregations.

GRAIN:
  One row per Branch + PartNumber + Franchise combination.

SOURCE TABLES (Lakehouse):
  InTrans_Incremental — transaction source (10M+ rows, incremental refresh)
  dim_Parts           — parts master for Description (manufacturer description)

DEMAND DEFINITION:
  A "demand" = one InTrans row where:
    - Type = "I"   (customer invoice — excludes transfers, adjustments, returns)
    - Qty  > 0     (outbound sale to customer; positive qty = sold for normal branches)
    - TransDatetime within the rolling window defined by MonthsBack
  This matches the methodology used in the Combine Vault Sales report
  (COUNTROWS of IsSale = TRUE transactions).

BRANCH 12 NOTE:
  Branch 12 is excluded from this table. Its transaction logic is inverted
  (negative Qty = sale), so TYPE = 'I' / Qty > 0 would miscount its demand.
  Branch 12 demand is tracked separately via the Combine Vault Sales report.

TIME WINDOW:
  Default: 12 months rolling (MonthsBack = 12).
  To expand to 18 months for a one-off analysis, change MonthsBack to 18.
  InTrans_Incremental holds 3 years of history, so up to 36 months is safe.

OUTPUT COLUMNS:
  Branch      — Branch code
  PartNumber  — Part number
  Description — Manufacturer part description (from dim_Parts)
  Franchise   — Franchise/manufacturer code
  Demands     — Count of customer invoice transactions in the rolling window

DATAFLOW PLACEMENT:
  Workspace:  LH_Master_Data
  Layer:      03 - Dimensions
  Dataflow:   df_dim_PartDemands
  Target:     LH_Master_Data Lakehouse → dim_PartDemands table
  Refresh:    Daily, Phase 3 (after InTrans_Incremental — Phase 2)

USAGE IN REPORTS:
  Join to dim_Parts or fact tables on PartNumber + Branch for demand context.
  In DAX: LOOKUPVALUE(dim_PartDemands[Demands],
              dim_PartDemands[PartNumber], [PartNumber],
              dim_PartDemands[Branch], [Branch])

CREATED: 2026-06-04
============================================================================
*/

let
    // ========================================================================
    // CONFIGURATION — adjust MonthsBack to change the rolling window
    // ========================================================================
    MonthsBack = 12,
    CutoffDate = DateTime.From(Date.AddMonths(Date.From(DateTime.LocalNow()), -MonthsBack)),

    // ========================================================================
    // STEP 1: LOAD INTRANS AND FILTER TO CUSTOMER SALES
    // ========================================================================
    Source = InTrans_Incremental,

    // Filter: customer invoice, outbound qty, within rolling window
    // Branch 12 excluded — its demand uses negative qty logic (see header note)
    FilteredRows = Table.SelectRows(Source, each
        [Type] = "I"
        and [Qty] > 0
        and [Branch] <> "12"
        and [TransDatetime] >= CutoffDate
    ),

    // ========================================================================
    // STEP 2: GROUP BY BRANCH / PART / FRANCHISE — COUNT TRANSACTIONS
    // ========================================================================
    Grouped = Table.Group(
        FilteredRows,
        {"Branch", "PartNumber", "Franchise"},
        {{"Demands", each Table.RowCount(_), Int64.Type}}
    ),

    // ========================================================================
    // STEP 3: JOIN TO DIM_PARTS FOR MANUFACTURER PART DESCRIPTION
    // ========================================================================
    // InTrans DESCRIPTION column is a customer/notation field — not a part description.
    // dim_Parts carries the real manufacturer description.
    PartsLookup    = Table.SelectColumns(dim_Parts, {"PartNumber", "Description"}),

    Joined   = Table.NestedJoin(
                   Grouped, {"PartNumber"},
                   PartsLookup, {"PartNumber"},
                   "Parts", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "Parts", {"Description"}),

    // ========================================================================
    // STEP 4: FINAL COLUMN SET, TYPES, AND SORT
    // ========================================================================
    Selected = Table.SelectColumns(Expanded,
        {"Branch", "PartNumber", "Description", "Franchise", "Demands"}),

    Typed = Table.TransformColumnTypes(Selected, {
        {"Branch",      type text},
        {"PartNumber",  type text},
        {"Description", type text},
        {"Franchise",   type text},
        {"Demands",     Int64.Type}
    }),

    Sorted = Table.Sort(Typed, {
        {"Franchise",  Order.Ascending},
        {"PartNumber", Order.Ascending},
        {"Branch",     Order.Ascending}
    })

in
    Sorted
