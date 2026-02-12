/*
============================================================================
Metadata Query: TableDescriptions
Source: SQL Anywhere Database (ODBC: EquipRDB64)
Purpose: Find tables with documented descriptions/remarks
============================================================================
*/

let
    Source = Odbc.Query("dsn=EquipRDB64", "-- Check if tables have remarks/comments
SELECT
    t.table_name,
    t.table_type,
    COALESCE(t.remarks, '') as table_description
FROM sys.systable t
WHERE t.creator NOT IN (1, 3)
    AND t.table_type IN ('BASE', 'VIEW')
    AND t.remarks IS NOT NULL
ORDER BY t.table_name;")
in
    Source
