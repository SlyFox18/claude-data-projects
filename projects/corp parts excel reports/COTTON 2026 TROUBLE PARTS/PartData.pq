/*
============================================================================
Query: PartData — COTTON 2026 TROUBLE PARTS.xlsx
Type: Excel Power Query (Advanced Editor) — Corp Parts Excel Reports library
Connection: ODBC — dsn=EquipRDB
Source Tables: jdis_Part_Information
============================================================================

PURPOSE:
Company-wide part lookup for Barry's cotton trouble-parts workbook: one row
per part number with its description and on-order / rolling-12-month sales
/ bin quantities summed across every branch. The workbook's own sheet
(Barry's list of trouble parts) looks parts up against this table.

LOGIC:
  - GROUP BY pi_Part_No across ALL branches and ALL franchises (no branch,
    franchise, or part-filter WHERE clause) — totals are company-wide.
  - Part numbers are upper-cased and trimmed so lookups from a hand-typed
    list match regardless of case or stray spaces.
  - Blank/null part numbers dropped.

OUTPUT COLUMNS:
  Part No      — pi_Part_No, trimmed + upper-cased (lookup key)
  Description  — MAX(pi_Description) across branches
  On Order     — SUM(pi_On_Order) across branches
  R12 Sales    — SUM(pi_current_12_mo_sales) across branches (units)
  Bin Qty      — SUM(pi_Bin_Qty) across branches

NOTES:
  - Not franchise-filtered: a part number carried under more than one
    franchise (e.g. 'D' and 'UD' — jdis's real grain is Branch + Part +
    Franchise) has all franchises' quantities summed together.
  - Pulls a full GROUP BY of jdis_Part_Information (~1.1M rows) on every
    refresh — fine on demand, but avoid refreshing repeatedly during the
    business day.
  - Built by Brian for Barry; first recorded in this repo 2026-10-07 (logic
    copied verbatim from the workbook, only reformatted from one line).

REQUESTED BY: Barry Sheets (cotton trouble-parts tracking), built by Brian
RECORDED: 2026-10-07
============================================================================

Power Query M — paste into Excel Advanced Editor:
*/

let
    Source = Odbc.Query("dsn=EquipRDB", "
        SELECT
            pi_Part_No,
            MAX(pi_Description)         AS Description,
            SUM(pi_On_Order)            AS On_Order,
            SUM(pi_current_12_mo_sales) AS R12_Sales,
            SUM(pi_Bin_Qty)             AS Bin_Qty
        FROM jdis_Part_Information
        GROUP BY pi_Part_No
    "),

    // Normalize the lookup key so a hand-typed list matches
    Trimmed = Table.TransformColumns(Source, {
        {"pi_Part_No",  each Text.Upper(Text.Trim(Text.From(_))), type text},
        {"Description", each Text.Trim(Text.From(_)),             type text}
    }),

    Typed = Table.TransformColumnTypes(Trimmed, {
        {"On_Order",  Int64.Type},
        {"R12_Sales", Int64.Type},
        {"Bin_Qty",   Int64.Type}
    }),

    NoBlanks = Table.SelectRows(Typed, each [pi_Part_No] <> null and [pi_Part_No] <> ""),

    Renamed = Table.RenameColumns(NoBlanks, {
        {"pi_Part_No", "Part No"},
        {"On_Order",   "On Order"},
        {"R12_Sales",  "R12 Sales"},
        {"Bin_Qty",    "Bin Qty"}
    })

in
    Renamed
