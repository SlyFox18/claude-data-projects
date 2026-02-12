/*
============================================================================
Metadata Query: UniqueConstraints
Source: SQL Anywhere Database (ODBC: EquipRDB64)
Purpose: Discover unique constraints for data integrity and potential keys
============================================================================
*/

let
    Source = Odbc.Query("dsn=EquipRDB64", "-- Find all unique constraints
SELECT
    t.table_name,
    idx.index_name as constraint_name,
    c.column_name
FROM sys.sysidx idx
INNER JOIN sys.systable t ON idx.table_id = t.table_id
INNER JOIN sys.sysidxcol ic ON idx.index_id = ic.index_id AND idx.table_id = ic.table_id
INNER JOIN sys.systabcol c ON ic.column_id = c.column_id AND ic.table_id = c.table_id
WHERE t.creator NOT IN (1, 3)
    AND idx.""unique"" = 1
    AND idx.index_category = 3  -- Unique constraint
ORDER BY t.table_name, idx.index_name, ic.sequence;")
in
    Source
