/*
============================================================================
Metadata Query: TimestampColumns
Source: SQL Anywhere Database (ODBC: EquipRDB64)
Purpose: Find all date/time columns - CRITICAL for incremental refresh
============================================================================

📋 RETURNS:
• table_name - Name of the table
• column_name - Name of the date/time column
• data_type - SQL Anywhere date/time type
• field_category - Created Date, Modified Date, Updated Date, Date Field, Time Field

🎯 COMMON USE CASES:
• "Which tables have ModifiedDate?" (incremental refresh)
• "What incremental refresh options exist?"
• "Which tables track creation timestamps?"
• "Find all audit date fields"

💡 INCREMENTAL REFRESH STRATEGY:
• Filter for field_category = 'Modified Date'
• Look for columns like: ModifiedDate, LastModified, UpdateDate
• Business date fields: InvoiceDate, SaleDate, RepairDate, CreationDate
• Use 2023+ scope for ModifiedDate fields (captures recent changes)

⚠️ CRITICAL FOR OPTIMIZATION:
Tables with ModifiedDate/CreationDate can use incremental refresh!
Currently implemented incremental refresh:
✅ TechnicianInvoiceDetail (ModifiedDate)
✅ TechnicianPunchedDetail (CreationDate)
✅ vhstock (SaleDate)
✅ WkInvReg (ModifiedDate)
✅ wkmechwk (ModifiedDate)
✅ wkothsub (ModifiedDate)
✅ WKROFILE (ModifiedDate)
✅ WKVEHFL (ModifiedDate)
✅ WarClaim (RepairDate) - NOT SCHEDULED

Potential candidates (have date fields but not yet incremental):
• armaster (has ModifiedDate)
• contact (has ModifiedDate)
• InHist_PmManage (has PeriodDate)
• RepairOrderDetail (has CreationDate)

============================================================================
*/

let
    Source = Odbc.Query("dsn=EquipRDB64", "-- Find all date/time columns (potential audit fields)
SELECT
    t.table_name,
    c.column_name,
    c.base_type_str as data_type,
    CASE
        WHEN LOWER(c.column_name) LIKE '%created%' THEN 'Created Date'
        WHEN LOWER(c.column_name) LIKE '%modified%' THEN 'Modified Date'
        WHEN LOWER(c.column_name) LIKE '%updated%' THEN 'Updated Date'
        WHEN LOWER(c.column_name) LIKE '%date%' THEN 'Date Field'
        WHEN LOWER(c.column_name) LIKE '%time%' THEN 'Time Field'
        ELSE 'Date/Time Field'
    END as field_category
FROM sys.systable t
INNER JOIN sys.systabcol c ON t.table_id = c.table_id
WHERE t.creator NOT IN (1, 3)
    AND t.table_type = 'BASE'
    AND (c.base_type_str LIKE '%date%'
         OR c.base_type_str LIKE '%time%'
         OR c.base_type_str LIKE '%stamp%')
ORDER BY t.table_name, c.column_name;")
in
    Source

/*
============================================================================
QUERY NOTES:

Field Categorization Logic:
• 'Created Date' - Columns with 'created' in name (insertion timestamp)
• 'Modified Date' - Columns with 'modified' in name (update timestamp)
• 'Updated Date' - Columns with 'updated' in name (update timestamp)
• 'Date Field' - General date columns (business dates)
• 'Time Field' - Time-specific columns

Incremental Refresh Best Practices:
1. ModifiedDate fields: Use 2023+ scope (RangeStart)
2. Business date fields: Use appropriate scope (e.g., 3 years for sales)
3. CreationDate fields: Good for immutable records
4. Avoid using business dates if records can be backdated

Common Date Field Patterns:
• ModifiedDate - Last update timestamp (BEST for incremental)
• CreationDate - Record creation timestamp
• InvoiceDate - Business date (use with caution)
• SaleDate - Business date (appropriate for sales data)
• RepairDate - Business date (appropriate for warranty data)

============================================================================
*/
