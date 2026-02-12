/*
============================================================================
Metadata Query: Views
Source: SQL Anywhere Database (ODBC: EquipRDB64)
Purpose: Discover all views and their columns
============================================================================
*/

let
    Source = Odbc.Query("dsn=EquipRDB64", "-- All views and their columns
SELECT
    t.table_name as view_name,
    c.column_name,
    c.base_type_str as data_type,
    c.width as column_length,
    c.column_id as ordinal_position,
    'View' as object_type
FROM sys.systable t
INNER JOIN sys.systabcol c ON t.table_id = c.table_id
WHERE t.creator NOT IN (1, 3)
    AND t.table_type = 'VIEW'
ORDER BY t.table_name, c.column_id;")
in
    Source
