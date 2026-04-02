/*
============================================================================
Dimension: dim_Salesperson
Dataflow:  df_dim_Salesperson
Location:  LH_Master_Data → Dataflows → 03 - Dimensions
============================================================================

📋 METADATA:
Purpose:  Salesperson master dimension — maps salesperson codes (S806, etc.)
          to full names and home branch. Shared dimension usable across any
          report that contains a Salesperson/SalespersonCode column.
Grain:    One row per salesperson code
Created:  2026-04-01
Output:   Lakehouse table "dim_Salesperson"

🔑 KEY DESIGN DECISIONS:
- Joins Salesperson (name) + SalespersonInformation (branch, status) on code
- IsTerminated = 'Y' rows are retained with an IsActive = false flag so
  historical fact data still resolves — do NOT filter them out
- SalespersonCode is the join key to fact tables (matches insalpar.Salesperson)
- DisplayName format: "S806 - John Smith" for charts/slicers
- FullName format: "John Smith" for clean display

🔗 DEPENDENCIES:
- Salesperson (source system table via dsn=EquipRDB64)
- SalespersonInformation (source system table via dsn=EquipRDB64)

🔗 SUGGESTED RELATIONSHIPS:
- Fact_MDInvoices_NoFreight[Salesperson] → dim_Salesperson[SalespersonCode]
- Any other fact table with a Salesperson column

⏱️ REFRESH:
- Full refresh, low volume (hundreds of rows)
- Add to Phase 3 (Dimensions) in Pipeline_Master_Orchestrator
- Can run in parallel with other dimension dataflows

============================================================================
*/

let

    // ========================================================================
    // STEP 1: LOAD SOURCE TABLES
    // ========================================================================

    RawSalesperson = Odbc.Query("dsn=EquipRDB64", "
        SELECT SalesPerson, FirstName, LastName
        FROM Salesperson
    "),

    RawSalespersonInfo = Odbc.Query("dsn=EquipRDB64", "
        SELECT SalespersonCode, Branch, IsTerminated
        FROM SalespersonInformation
    "),


    // ========================================================================
    // STEP 2: CLEAN AND STANDARDIZE EACH TABLE
    // ========================================================================

    CleanSalesperson = Table.TransformColumns(RawSalesperson, {
        {"SalesPerson",  each Text.Upper(Text.Trim(_ ?? "")), type text},
        {"FirstName",    each Text.Proper(Text.Trim(_ ?? "")), type text},
        {"LastName",     each Text.Proper(Text.Trim(_ ?? "")), type text}
    }),

    CleanSalespersonInfo = Table.TransformColumns(RawSalespersonInfo, {
        {"SalespersonCode", each Text.Upper(Text.Trim(_ ?? "")), type text},
        {"Branch",          each Text.Trim(_ ?? ""), type text},
        {"IsTerminated",    each _, type any}
    }),

    // Deduplicate SalespersonInformation on code (keep first row per code)
    DedupeInfo = Table.Distinct(CleanSalespersonInfo, {"SalespersonCode"}),


    // ========================================================================
    // STEP 3: JOIN NAME + INFO
    // Left join from Salesperson — preserves all codes even if no info row
    // ========================================================================

    Joined = Table.NestedJoin(
        CleanSalesperson,   {"SalesPerson"},
        DedupeInfo,         {"SalespersonCode"},
        "InfoRow",          JoinKind.LeftOuter
    ),

    Expanded = Table.ExpandTableColumn(
        Joined, "InfoRow",
        {"Branch", "IsTerminated"},
        {"Branch", "IsTerminated"}
    ),


    // ========================================================================
    // STEP 4: ADD CALCULATED COLUMNS
    // ========================================================================

    AddFullName = Table.AddColumn(Expanded, "FullName", each
        let
            first = [FirstName],
            last  = [LastName]
        in
            if first <> "" and last <> "" then first & " " & last
            else if last  <> "" then last
            else if first <> "" then first
            else [SalesPerson],
        type text
    ),

    AddDisplayName = Table.AddColumn(AddFullName, "DisplayName", each
        [SalesPerson] & " - " & [FullName],
        type text
    ),

    AddIsActive = Table.AddColumn(AddDisplayName, "IsActive", each
        let
            val = [IsTerminated]
        in
            if val = null then true
            else if val = 1 or val = "1" or Text.Upper(Text.From(val)) = "Y" then false
            else true,
        type logical
    ),


    // ========================================================================
    // STEP 5: RENAME AND SELECT FINAL COLUMNS
    // ========================================================================

    Renamed = Table.RenameColumns(AddIsActive, {
        {"SalesPerson", "SalespersonCode"},
        {"FirstName",   "FirstName"},
        {"LastName",    "LastName"}
    }),

    SelectFinal = Table.SelectColumns(Renamed, {
        "SalespersonCode",
        "FirstName",
        "LastName",
        "FullName",
        "DisplayName",
        "Branch",
        "IsActive"
    }),


    // ========================================================================
    // STEP 6: SET DATA TYPES AND SORT
    // ========================================================================

    SetTypes = Table.TransformColumnTypes(SelectFinal, {
        {"SalespersonCode", type text},
        {"FirstName",       type text},
        {"LastName",        type text},
        {"FullName",        type text},
        {"DisplayName",     type text},
        {"Branch",          type text},
        {"IsActive",        type logical}
    }),

    Sorted = Table.Sort(SetTypes, {{"SalespersonCode", Order.Ascending}})

in
    Sorted

/*
============================================================================
✅ VALIDATION (run at Lakehouse SQL endpoint after first refresh)
============================================================================

-- 1. Row count
SELECT COUNT(*) AS RowCount FROM dim_Salesperson;

-- 2. Active vs terminated split
SELECT IsActive, COUNT(*) AS Count FROM dim_Salesperson GROUP BY IsActive;

-- 3. No duplicate codes
SELECT SalespersonCode, COUNT(*) AS Cnt
FROM dim_Salesperson
GROUP BY SalespersonCode
HAVING COUNT(*) > 1;

-- 4. Any codes in fact table not in dim (orphan check)
SELECT DISTINCT f.Salesperson
FROM Fact_MDInvoices_NoFreight f
LEFT JOIN dim_Salesperson d ON f.Salesperson = d.SalespersonCode
WHERE d.SalespersonCode IS NULL;

============================================================================
*/
