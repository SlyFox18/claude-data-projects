/*
============================================================================
ADHOC: Parts with User Field 2 (all parts, unfiltered)
============================================================================
Purpose:   Return a curated subset of jdis_Part_Information columns +
           user_field_2 from InMaster, scoped to the branches/franchises
           Shannon actually orders for. No row filter on user_field_2
           itself — blank/null UserField2 rows are included so the full
           (scoped) part population is visible. Joined via LEFT JOIN (not
           INNER) so parts with no matching InMaster record still come
           through, with UserField2 null. The SQL SELECT lists only the
           ~30 columns this report needs (instead of pi.*) and aliases
           each to its final stripped name in the exact order the report
           wants — no post-processing needed in M.
Row scope: WHERE excludes Franchise IN ('BW','C','DA','HW','ZP','S','TD',
           'TM','UD','UM','W','D') and Branch IN ('5','12','97'). Per
           Brian/Shannon 2026-09-02: total jdis_Part_Information is
           ~1.1M rows, franchise D alone is ~700-800k of that — excluding
           D plus the other listed franchises and branches brings this
           down to an estimated ~200k rows, the population Shannon
           actually works with for parts ordering.
Perf note: Column names below assume every jdis_Part_Information column
           follows the "pi_" prefix convention — confirmed for most of
           these fields against .claude/queries/raw-tables/jdis_Part_Information.pq
           (the shared raw-table definition). If a refresh errors on an
           unrecognized column, that field's real source name differs
           from this assumption — check it against the actual schema.
Grain:     One row per part per branch
Source:    ODBC - dsn=EquipRDB64
Join Key:  pi_Branch = BRANCH, pi_Part_No = PART_NO
Requested: Parts manager - ad-hoc, refreshed manually as needed

HOW TO USE IN EXCEL
-------------------
OPTION A — Excel ODBC dialog (simplest):
  Data → Get Data → From ODBC → EquipRDB64
  Expand "Advanced Options" → paste the SQL below into "SQL Statement"
  Load → Done. Refresh anytime via Data → Refresh All.

OPTION B — Power Query Advanced Editor:
  Data → Get Data → Launch Power Query Editor
  Home → New Source → Blank Query → Advanced Editor
  Paste the M code (the let...in block below) → Done.

RAW SQL (use for Option A — column list matches the M code below):
  SELECT im.user_field_2 AS UserField2, pi.pi_Branch AS Branch, ... (see
  M code below for the full ~30-column list; too long to repeat here)
  FROM jdis_Part_Information pi
  LEFT JOIN InMaster im ON pi.pi_Branch = im.BRANCH AND pi.pi_Part_No = im.PART_NO
  WHERE pi.pi_Franchise NOT IN ('BW','C','DA','HW','ZP','S','TD','TM','UD','UM','W','D')
    AND pi.pi_Branch NOT IN ('5','12','97')

UPDATED: 2026-09-01 — removed the user_field_2 IS NOT NULL / non-blank
  filter; now returns every part regardless of whether UserField2 is set
UPDATED: 2026-09-01 — added column reorder (UserField2 first) + column
  filter, trimming jdis_Part_Information's ~230 columns down to the
  fields needed for this report
UPDATED: 2026-09-01 — switched InMaster join from INNER to LEFT so parts
  with no InMaster record still appear (UserField2 comes back null)
UPDATED: 2026-09-02 — collapsed the reorder + column-select into a single
  Table.SelectColumns step (perf: was doing a full-table reorder across
  all ~230 columns before trimming down to ~90; no output change)
UPDATED: 2026-09-02 (perf) — replaced `pi.*` with an explicit ~90-column
  SQL SELECT list (aliased to final names, matching the SELECT order) and
  dropped ORDER BY; this pushes the column trim down to the source so
  ODBC transfers far less data, and skips a source-side full sort that
  bought nothing for an Import-mode PBI model. StripPrefix and the
  Table.SelectColumns step are gone too — the SQL now does that work
  directly, so Source is the final output.
UPDATED: 2026-09-02 (scope, per Shannon) — dropped the entire
  current_mo_requests / sales_request_02..60 column family (not needed);
  added a WHERE clause excluding franchises BW, C, DA, HW, ZP, S, TD, TM,
  UD, UM, W, D and branches 5, 12, 97 — scopes ~1.1M rows down to an
  estimated ~200k, the population Shannon actually orders for. This is
  the first "master (slow) tier" pass of a planned two-tier design — see
  this project's CLAUDE.md for the fast/hourly inventory-tier plan.
============================================================================
*/

// M CODE — paste into Power Query Advanced Editor (Option B only)
let
    Source = Odbc.Query(
        "dsn=EquipRDB64",
        "SELECT " &
        "im.user_field_2 AS UserField2, " &
        "pi.pi_Branch AS Branch, " &
        "pi.pi_Franchise AS Franchise, " &
        "pi.pi_Part_No AS Part_No, " &
        "pi.pi_Description AS Description, " &
        "pi.pi_Vendor_Code AS Vendor_Code, " &
        "pi.pi_Bin AS Bin, " &
        "pi.pi_Dealer_Group_Code AS Dealer_Group_Code, " &
        "pi.pi_Bin_Qty AS Bin_Qty, " &
        "pi.pi_On_Order AS On_Order, " &
        "pi.pi_Cost AS Cost, " &
        "pi.pi_In_Transit_Qty AS In_Transit_Qty, " &
        "pi.pi_Pending_Qty AS Pending_Qty, " &
        "pi.pi_Inventory_Cost AS Inventory_Cost, " &
        "pi.pi_current_mo_sales AS current_mo_sales, " &
        "pi.pi_sales_history_02 AS sales_history_02, " &
        "pi.pi_sales_history_03 AS sales_history_03, " &
        "pi.pi_sales_history_04 AS sales_history_04, " &
        "pi.pi_sales_history_05 AS sales_history_05, " &
        "pi.pi_sales_history_06 AS sales_history_06, " &
        "pi.pi_sales_history_07 AS sales_history_07, " &
        "pi.pi_sales_history_08 AS sales_history_08, " &
        "pi.pi_sales_history_09 AS sales_history_09, " &
        "pi.pi_sales_history_10 AS sales_history_10, " &
        "pi.pi_sales_history_11 AS sales_history_11, " &
        "pi.pi_sales_history_12 AS sales_history_12, " &
        "pi.pi_sales_history_13 AS sales_history_13, " &
        "pi.pi_sales_history_14 AS sales_history_14, " &
        "pi.pi_sales_history_15 AS sales_history_15, " &
        "pi.pi_sales_history_16 AS sales_history_16, " &
        "pi.pi_sales_history_17 AS sales_history_17, " &
        "pi.pi_sales_history_18 AS sales_history_18, " &
        "pi.pi_sales_history_19 AS sales_history_19, " &
        "pi.pi_sales_history_20 AS sales_history_20, " &
        "pi.pi_sales_history_21 AS sales_history_21, " &
        "pi.pi_sales_history_22 AS sales_history_22, " &
        "pi.pi_sales_history_23 AS sales_history_23, " &
        "pi.pi_sales_history_24 AS sales_history_24, " &
        "pi.pi_sales_history_25 AS sales_history_25, " &
        "pi.pi_sales_history_26 AS sales_history_26, " &
        "pi.pi_sales_history_27 AS sales_history_27, " &
        "pi.pi_sales_history_28 AS sales_history_28, " &
        "pi.pi_sales_history_29 AS sales_history_29, " &
        "pi.pi_sales_history_30 AS sales_history_30, " &
        "pi.pi_sales_history_31 AS sales_history_31, " &
        "pi.pi_sales_history_32 AS sales_history_32, " &
        "pi.pi_sales_history_33 AS sales_history_33, " &
        "pi.pi_sales_history_34 AS sales_history_34, " &
        "pi.pi_sales_history_35 AS sales_history_35, " &
        "pi.pi_sales_history_36 AS sales_history_36, " &
        "pi.pi_sales_history_37 AS sales_history_37, " &
        "pi.pi_sales_history_38 AS sales_history_38, " &
        "pi.pi_sales_history_39 AS sales_history_39, " &
        "pi.pi_sales_history_40 AS sales_history_40, " &
        "pi.pi_sales_history_41 AS sales_history_41, " &
        "pi.pi_sales_history_42 AS sales_history_42, " &
        "pi.pi_sales_history_43 AS sales_history_43, " &
        "pi.pi_sales_history_44 AS sales_history_44, " &
        "pi.pi_sales_history_45 AS sales_history_45, " &
        "pi.pi_sales_history_46 AS sales_history_46, " &
        "pi.pi_sales_history_47 AS sales_history_47, " &
        "pi.pi_sales_history_48 AS sales_history_48, " &
        "pi.pi_sales_history_49 AS sales_history_49, " &
        "pi.pi_sales_history_50 AS sales_history_50, " &
        "pi.pi_sales_history_51 AS sales_history_51, " &
        "pi.pi_sales_history_52 AS sales_history_52, " &
        "pi.pi_sales_history_53 AS sales_history_53, " &
        "pi.pi_sales_history_54 AS sales_history_54, " &
        "pi.pi_sales_history_55 AS sales_history_55, " &
        "pi.pi_sales_history_56 AS sales_history_56, " &
        "pi.pi_sales_history_57 AS sales_history_57, " &
        "pi.pi_sales_history_58 AS sales_history_58, " &
        "pi.pi_sales_history_59 AS sales_history_59, " &
        "pi.pi_sales_history_60 AS sales_history_60 " &
        "FROM jdis_Part_Information pi " &
        "LEFT JOIN InMaster im " &
            "ON pi.pi_Branch = im.BRANCH AND pi.pi_Part_No = im.PART_NO " &
        "WHERE " &
        "pi.pi_Franchise NOT IN ('BW','C','DA','HW','ZP','S','TD','TM','UD','UM','W','D') " &
        "AND pi.pi_Branch NOT IN ('5','12','97')"
    )
    // No M-side rename/reorder/select needed anymore — the SQL SELECT above
    // already aliases every column to its final stripped name (e.g.
    // pi_Branch AS Branch) and lists them in the exact order the report
    // wants (UserField2 first), so Source is the finished table.
in
    Source
