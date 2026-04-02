/*
============================================================================
Query: Source System Table Search — insalord history / freight tables
Purpose: Search SQL Anywhere source system for insalord-related tables
         (history, archive, posted) and any tables with freight columns.
         Used to identify Phase 2 data source candidates.
Run in: Power BI Desktop → Transform Data → New Query → Advanced Editor
NOTE: Uses SYSTABLE (no sys. prefix) — correct for this SQL Anywhere ODBC driver
============================================================================
*/

let
    SQL = "SELECT table_name, table_type FROM SYSTABLE WHERE LOWER(table_name) LIKE '%insal%' OR LOWER(table_name) LIKE '%freight%' ORDER BY table_name",

    Source = Odbc.Query("dsn=EquipRDB64", SQL)
in
    Source

/*
WHAT TO LOOK FOR:
- insalordh, insalord_hist, insalord_archive → header history table (Phase 2)
- insalparh, insalpar_hist                   → line item history table (Phase 2)
- Any table with 'freight' in name

NEXT STEP: If history tables are found, run a follow-up query to see their columns:
    "SELECT c.column_name, c.domain_name FROM SYSTABLE t, SYSCOLUMN c WHERE t.table_id = c.table_id AND t.table_name = 'TABLENAME_HERE' ORDER BY c.column_name"

DO NOT PUBLISH — exploration query only, delete when done.
*/
