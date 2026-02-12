/*
============================================================================
Metadata Query: Indexes
Source: SQL Anywhere Database (ODBC: EquipRDB64)
Purpose: Understand indexing strategy for query optimization
============================================================================
*/

let
    Source = Odbc.Query("dsn=EquipRDB64", "-- All indexes and their columns
SELECT
    t.table_name,
    idx.index_name,
    c.column_name,
    CASE idx.index_category
        WHEN 1 THEN 'Primary Key'
        WHEN 2 THEN 'Foreign Key'
        WHEN 3 THEN 'Unique'
        WHEN 4 THEN 'Non-Unique'
        ELSE 'Other'
    END as index_type,
    CASE WHEN idx.""unique"" = 1 THEN 'Yes' ELSE 'No' END as is_unique,
    ic.sequence as column_order_in_index
FROM sys.sysidx idx
INNER JOIN sys.systable t ON idx.table_id = t.table_id
INNER JOIN sys.sysidxcol ic ON idx.index_id = ic.index_id AND idx.table_id = ic.table_id
INNER JOIN sys.systabcol c ON ic.column_id = c.column_id AND ic.table_id = c.table_id
WHERE t.creator NOT IN (1, 3)
    AND t.table_type = 'BASE'
ORDER BY t.table_name, idx.index_name, ic.sequence;")
in
    Source
