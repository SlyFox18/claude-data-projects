/*
============================================================================
Metadata Query: TableColumns
Source: SQL Anywhere Database (ODBC: EquipRDB64)
Purpose: Complete schema discovery - every table and column with metadata
============================================================================

📋 RETURNS:
• table_name - Name of the table
• column_name - Name of the column
• data_type - SQL Anywhere data type
• column_length - Width/length of the column
• decimal_scale - Scale for numeric columns
• is_nullable - Whether NULL values allowed (Yes/No)
• default_value - Default value if defined
• ordinal_position - Column order in table
• table_row_count - Number of rows in table
• is_primary_key - Whether column is primary key (Yes/No)

🎯 COMMON USE CASES:
• "Which table has the 'ModifiedDate' column?"
• "What's the data type of 'InvoiceNumber'?"
• "Which columns are nullable in WKROFILE?"
• "What are all the primary keys?"

💡 TIPS:
• Filter by column_name to find where a field exists across tables
• Filter by is_primary_key = 'Yes' to find all PKs
• Sort by table_row_count to identify large tables
• Use with TimestampColumns.pq to find incremental refresh candidates

============================================================================
*/

let
    Source = Odbc.Query("dsn=EquipRDB64", "-- Optimized for your SQL Anywhere version
SELECT
    t.table_name,
    c.column_name,
    c.base_type_str as data_type,
    c.width as column_length,
    c.scale as decimal_scale,
    CASE WHEN c.nulls = 'Y' THEN 'Yes' ELSE 'No' END as is_nullable,
    c.""default"" as default_value,
    c.column_id as ordinal_position,
    t.count as table_row_count,
    CASE WHEN idx.index_name IS NOT NULL THEN 'Yes' ELSE 'No' END as is_primary_key
FROM sys.systable t
INNER JOIN sys.systabcol c ON t.table_id = c.table_id
LEFT JOIN sys.sysidxcol ic ON c.column_id = ic.column_id AND c.table_id = ic.table_id
LEFT JOIN sys.sysidx idx ON ic.index_id = idx.index_id AND ic.table_id = idx.table_id AND idx.index_category = 1
WHERE t.creator NOT IN (1, 3)
    AND t.table_type = 'BASE'
ORDER BY t.table_name, c.column_id;")
in
    Source

/*
============================================================================
QUERY NOTES:

System Tables Used:
• sys.systable - Table metadata (includes row counts)
• sys.systabcol - Column metadata (types, nullability, defaults)
• sys.sysidx - Index metadata (identifies primary keys)
• sys.sysidxcol - Index-column mappings

Filtering Logic:
• creator NOT IN (1, 3) - Excludes system tables (SYS, dbo)
• table_type = 'BASE' - Returns only base tables (not views)
• index_category = 1 - Identifies primary key indexes

Performance:
• Reads from system catalog (very fast)
• Safe to run frequently
• No impact on production data

============================================================================
*/
