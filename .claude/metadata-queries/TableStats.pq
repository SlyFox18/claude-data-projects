/*
============================================================================
Metadata Query: TableStats
Source: SQL Anywhere Database (ODBC: EquipRDB64)
Purpose: Capacity planning and optimization - table sizes and row counts
============================================================================
*/

let
    Source = Odbc.Query("dsn=EquipRDB64", "-- Table statistics (size and row counts)
SELECT
    t.table_name,
    t.table_type,
    t.count as row_count,
    t.table_page_count as storage_pages,
    COALESCE(t.remarks, '') as table_description
FROM sys.systable t
WHERE t.creator NOT IN (1, 3)
    AND t.table_type = 'BASE'
ORDER BY t.count DESC;")
in
    Source
