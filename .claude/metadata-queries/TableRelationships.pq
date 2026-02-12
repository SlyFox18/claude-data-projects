/*
============================================================================
Metadata Query: TableRelationships
Source: SQL Anywhere Database (ODBC: EquipRDB64)
Purpose: Discover foreign key relationships between tables
============================================================================

📋 RETURNS:
• primary_table - Parent table with primary key
• foreign_table - Child table with foreign key
• relationship_name - FK constraint role/name
• foreign_key_column - Column in child table
• references_column - Column in parent table

🎯 COMMON USE CASES:
• "How do I join WKROFILE to other tables?"
• "What tables depend on InMaster?"
• "What's the relationship between Invoice and WkInvReg?"
• "Map all table dependencies"

💡 TIPS:
• Filter by foreign_table to find all dependencies for a table
• Filter by primary_table to find all child tables
• Group by relationship_name for composite FK relationships
• Use with TableColumns.pq to verify column names

⚠️ IMPORTANT:
• Shows ONLY explicitly defined FK constraints
• Source system may use implicit relationships not shown here
• Consult RAW-TABLES-SUMMARY.md for documented relationships

============================================================================
*/

let
    Source = Odbc.Query("dsn=EquipRDB64", "-- Foreign key relationships (confirmed for your version)
SELECT
    pt.table_name as primary_table,
    ft.table_name as foreign_table,
    fk.role as relationship_name,
    fc.column_name as foreign_key_column,
    pc.column_name as references_column
FROM sys.sysforeignkey fk
INNER JOIN sys.systable pt ON fk.primary_table_id = pt.table_id
INNER JOIN sys.systable ft ON fk.foreign_table_id = ft.table_id
INNER JOIN sys.sysfkcol fkc ON fk.foreign_key_id = fkc.foreign_key_id
INNER JOIN sys.systabcol fc ON fkc.foreign_column_id = fc.column_id AND fc.table_id = ft.table_id
INNER JOIN sys.systabcol pc ON fkc.primary_column_id = pc.column_id AND pc.table_id = pt.table_id
WHERE pt.creator NOT IN (1, 3) AND ft.creator NOT IN (1, 3)
ORDER BY ft.table_name, fk.role;")
in
    Source

/*
============================================================================
QUERY NOTES:

System Tables Used:
• sys.sysforeignkey - FK metadata
• sys.systable - Table names
• sys.sysfkcol - FK column mappings
• sys.systabcol - Column names

Relationship Example:
primary_table: WKROFILE
foreign_table: wkmechwk
foreign_key_column: RO_NUMBER
references_column: RO_NUMBER
relationship_name: FK_wkmechwk_WKROFILE

Composite FK Relationships:
• Multiple rows with same relationship_name
• Each row represents one column in the composite key

============================================================================
*/
