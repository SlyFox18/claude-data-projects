/*
============================================================================
ADHOC: Parts with User Field 2 Values
============================================================================
Purpose:   Return all jdis_Part_Information columns + user_field_2 from
           InMaster, filtered to only parts where user_field_2 has a value.
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

RAW SQL (use for Option A):
  SELECT pi.*, im.user_field_2 AS UserField2
  FROM jdis_Part_Information pi
  INNER JOIN InMaster im ON pi.pi_Branch = im.BRANCH AND pi.pi_Part_No = im.PART_NO
  WHERE im.user_field_2 IS NOT NULL AND TRIM(im.user_field_2) <> ''
  ORDER BY pi.pi_Branch, pi.pi_Part_No
============================================================================
*/

// M CODE — paste into Power Query Advanced Editor (Option B only)
let
    Source = Odbc.Query(
        "dsn=EquipRDB64",
        "SELECT pi.*, im.user_field_2 AS UserField2 " &
        "FROM jdis_Part_Information pi " &
        "INNER JOIN InMaster im " &
            "ON pi.pi_Branch = im.BRANCH AND pi.pi_Part_No = im.PART_NO " &
        "WHERE im.user_field_2 IS NOT NULL AND TRIM(im.user_field_2) <> '' " &
        "ORDER BY pi.pi_Branch, pi.pi_Part_No"
    ),
    // Strip the "pi_" prefix from all jdis columns; UserField2 is unaffected
    StripPrefix = Table.RenameColumns(
        Source,
        List.Transform(
            Table.ColumnNames(Source),
            each {_, if Text.StartsWith(_, "pi_") then Text.Middle(_, 3) else _}
        )
    )
in
    StripPrefix
