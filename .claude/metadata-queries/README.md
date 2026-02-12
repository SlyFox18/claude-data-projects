# Database Metadata Queries

**Purpose**: Query the SQL Anywhere source database to discover schema information, relationships, and metadata for troubleshooting and development.

**Source**: SQL Anywhere Database (ODBC: EquipRDB64)

**Power BI Report**: These queries power the "Table-Column-Names-Search" report

---

## Quick Reference

| Query | Purpose | Use When |
|-------|---------|----------|
| [TableColumns.pq](#tablecolumnspq) | All tables and their columns with data types | Finding which table has a specific field |
| [TableRelationships.pq](#tablerelationshipspq) | Foreign key relationships between tables | Understanding how tables connect |
| [Views.pq](#viewspq) | All views and their columns | Exploring available views |
| [Indexes.pq](#indexespq) | All indexes and their columns | Understanding query performance |
| [TableDescriptions.pq](#tabledescriptionspq) | Tables with remarks/comments | Finding documented tables |
| [TableStats.pq](#tablestatspq) | Table sizes and row counts | Capacity planning and optimization |
| [TimestampColumns.pq](#timestampcolumnspq) | All date/time columns with categorization | Finding incremental refresh candidates |
| [UniqueConstraints.pq](#uniqueconstraintspq) | All unique constraints | Understanding data integrity rules |

---

## Query Details

### TableColumns.pq

**Purpose**: Complete schema discovery - every table and column with full metadata

**Returns**:
- `table_name` - Name of the table
- `column_name` - Name of the column
- `data_type` - SQL Anywhere data type
- `column_length` - Width/length of the column
- `decimal_scale` - Scale for numeric columns
- `is_nullable` - Whether NULL values allowed (Yes/No)
- `default_value` - Default value if defined
- `ordinal_position` - Column order in table
- `table_row_count` - Number of rows in table
- `is_primary_key` - Whether column is primary key (Yes/No)

**Common Use Cases**:
- 🔍 "Which table has the 'ModifiedDate' column?"
- 🔍 "What's the data type of 'InvoiceNumber'?"
- 🔍 "Which columns are nullable in WKROFILE?"
- 🔍 "What are all the primary keys?"

**Query**:
```sql
SELECT
    t.table_name,
    c.column_name,
    c.base_type_str as data_type,
    c.width as column_length,
    c.scale as decimal_scale,
    CASE WHEN c.nulls = 'Y' THEN 'Yes' ELSE 'No' END as is_nullable,
    c."default" as default_value,
    c.column_id as ordinal_position,
    t.count as table_row_count,
    CASE WHEN idx.index_name IS NOT NULL THEN 'Yes' ELSE 'No' END as is_primary_key
FROM sys.systable t
INNER JOIN sys.systabcol c ON t.table_id = c.table_id
LEFT JOIN sys.sysidxcol ic ON c.column_id = ic.column_id AND c.table_id = ic.table_id
LEFT JOIN sys.sysidx idx ON ic.index_id = idx.index_id AND ic.table_id = idx.table_id AND idx.index_category = 1
WHERE t.creator NOT IN (1, 3)
    AND t.table_type = 'BASE'
ORDER BY t.table_name, c.column_id;
```

**Notes**:
- `creator NOT IN (1, 3)` filters out system tables (1=SYS, 3=dbo system)
- `table_type = 'BASE'` returns only base tables (not views)
- `index_category = 1` identifies primary key indexes

---

### TableRelationships.pq

**Purpose**: Discover foreign key relationships between tables

**Returns**:
- `primary_table` - Parent table with primary key
- `foreign_table` - Child table with foreign key
- `relationship_name` - FK constraint role/name
- `foreign_key_column` - Column in child table
- `references_column` - Column in parent table

**Common Use Cases**:
- 🔗 "How do I join WKROFILE to other tables?"
- 🔗 "What tables depend on InMaster?"
- 🔗 "What's the relationship between Invoice and WkInvReg?"
- 🔗 "Map all table dependencies"

**Query**:
```sql
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
ORDER BY ft.table_name, fk.role;
```

**Notes**:
- Groups by foreign table (child) for easier reading
- Shows both the FK column name and what it references
- Relationship name provides context for the link

---

### Views.pq

**Purpose**: Discover all views and their columns

**Returns**:
- `view_name` - Name of the view
- `column_name` - Column in the view
- `data_type` - SQL Anywhere data type
- `column_length` - Width/length
- `ordinal_position` - Column order
- `object_type` - Always "View"

**Common Use Cases**:
- 👁️ "What views are available?"
- 👁️ "What columns does this view have?"
- 👁️ "Should I use a view or the base table?"

**Query**:
```sql
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
ORDER BY t.table_name, c.column_id;
```

**Notes**:
- `table_type = 'VIEW'` filters to views only
- Views may join multiple tables or provide computed columns
- Check view definition before using in production queries

---

### Indexes.pq

**Purpose**: Understand indexing strategy for query optimization

**Returns**:
- `table_name` - Table with the index
- `index_name` - Name of the index
- `column_name` - Column in the index
- `index_type` - Primary Key, Foreign Key, Unique, Non-Unique, Other
- `is_unique` - Whether index enforces uniqueness (Yes/No)
- `column_order_in_index` - Order in composite index

**Common Use Cases**:
- ⚡ "Why is my query slow?"
- ⚡ "What indexes exist on WKROFILE?"
- ⚡ "Which columns are indexed for fast lookups?"
- ⚡ "What's the composite key structure?"

**Query**:
```sql
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
    CASE WHEN idx."unique" = 1 THEN 'Yes' ELSE 'No' END as is_unique,
    ic.sequence as column_order_in_index
FROM sys.sysidx idx
INNER JOIN sys.systable t ON idx.table_id = t.table_id
INNER JOIN sys.sysidxcol ic ON idx.index_id = ic.index_id AND idx.table_id = ic.table_id
INNER JOIN sys.systabcol c ON ic.column_id = c.column_id AND ic.table_id = c.table_id
WHERE t.creator NOT IN (1, 3)
    AND t.table_type = 'BASE'
ORDER BY t.table_name, idx.index_name, ic.sequence;
```

**Notes**:
- Composite indexes show multiple rows (one per column)
- `column_order_in_index` shows the order in composite keys
- Primary/foreign keys automatically create indexes

---

### TableDescriptions.pq

**Purpose**: Find tables with documented descriptions/remarks

**Returns**:
- `table_name` - Name of the table
- `table_type` - BASE or VIEW
- `table_description` - Comments/remarks if present

**Common Use Cases**:
- 📝 "What does this table contain?"
- 📝 "Which tables are documented?"
- 📝 "What's the business purpose?"

**Query**:
```sql
SELECT
    t.table_name,
    t.table_type,
    COALESCE(t.remarks, '') as table_description
FROM sys.systable t
WHERE t.creator NOT IN (1, 3)
    AND t.table_type IN ('BASE', 'VIEW')
    AND t.remarks IS NOT NULL
ORDER BY t.table_name;
```

**Notes**:
- Only returns tables WITH remarks (may return few results)
- Source system may not have extensive documentation
- Use `.claude/queries/raw-tables/` documentation as primary reference

---

### TableStats.pq

**Purpose**: Capacity planning and optimization - table sizes and row counts

**Returns**:
- `table_name` - Name of the table
- `table_type` - BASE or VIEW
- `row_count` - Current number of rows
- `storage_pages` - Number of storage pages used
- `table_description` - Comments if present

**Common Use Cases**:
- 📊 "Which tables are largest?"
- 📊 "How many rows in WKROFILE?"
- 📊 "What's the storage impact?"
- 📊 "Which tables should use incremental refresh?"

**Query**:
```sql
SELECT
    t.table_name,
    t.table_type,
    t.count as row_count,
    t.table_page_count as storage_pages,
    COALESCE(t.remarks, '') as table_description
FROM sys.systable t
WHERE t.creator NOT IN (1, 3)
    AND t.table_type = 'BASE'
ORDER BY t.count DESC;
```

**Notes**:
- Ordered by row count (largest first)
- `storage_pages` indicates disk space usage
- Use for identifying incremental refresh candidates

---

### TimestampColumns.pq

**Purpose**: Find all date/time columns - **CRITICAL for incremental refresh**

**Returns**:
- `table_name` - Name of the table
- `column_name` - Name of the date/time column
- `data_type` - SQL Anywhere date/time type
- `field_category` - Categorized as Created Date, Modified Date, Updated Date, Date Field, Time Field

**Common Use Cases**:
- 🕐 "Which tables have ModifiedDate?"
- 🕐 "What incremental refresh options exist?"
- 🕐 "Which tables track creation timestamps?"
- 🕐 "Find all audit date fields"

**Query**:
```sql
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
ORDER BY t.table_name, c.column_name;
```

**Notes**:
- **ESSENTIAL for identifying incremental refresh opportunities**
- `field_category` helps identify audit fields (Created, Modified)
- Filter for "Modified Date" to find incremental refresh candidates

**Incremental Refresh Reference**:
- ✅ Tables with `ModifiedDate`: armaster, contact, TechnicianInvoiceDetail, WkInvReg, wkmechwk, wkothsub, WKROFILE, WKVEHFL
- ✅ Tables with `CreationDate`: RepairOrderDetail, TechnicianPunchedDetail
- ✅ Business dates: InvoiceDate (Invoice), SaleDate (vhstock), RepairDate (WarClaim)

---

### UniqueConstraints.pq

**Purpose**: Discover unique constraints for data integrity and potential keys

**Returns**:
- `table_name` - Name of the table
- `constraint_name` - Name of the unique constraint/index
- `column_name` - Column that must be unique

**Common Use Cases**:
- 🔑 "What are the natural keys?"
- 🔑 "Which columns enforce uniqueness?"
- 🔑 "What are the business keys?"
- 🔑 "Find alternate keys for joining"

**Query**:
```sql
SELECT
    t.table_name,
    idx.index_name as constraint_name,
    c.column_name
FROM sys.sysidx idx
INNER JOIN sys.systable t ON idx.table_id = t.table_id
INNER JOIN sys.sysidxcol ic ON idx.index_id = ic.index_id AND idx.table_id = ic.table_id
INNER JOIN sys.systabcol c ON ic.column_id = c.column_id AND ic.table_id = c.table_id
WHERE t.creator NOT IN (1, 3)
    AND idx."unique" = 1
    AND idx.index_category = 3  -- Unique constraint
ORDER BY t.table_name, idx.index_name, ic.sequence;
```

**Notes**:
- `index_category = 3` filters to unique constraints (excludes PKs)
- Composite unique constraints show multiple rows
- Useful for understanding business key structure

---

## Usage Examples

### Example 1: Finding Incremental Refresh Candidates

```powerquery
// Use TimestampColumns.pq to find tables with ModifiedDate
// Filter results to: field_category = "Modified Date"
// Result: List of all tables that support incremental refresh
```

### Example 2: Understanding Table Relationships

```powerquery
// Use TableRelationships.pq
// Filter to: foreign_table = "WKROFILE"
// Result: All tables that reference WKROFILE (child tables)
```

### Example 3: Schema Exploration for New Raw Table

```powerquery
// 1. Use TableStats.pq to find table and row count
// 2. Use TableColumns.pq to see all columns and types
// 3. Use Indexes.pq to understand primary keys
// 4. Use TimestampColumns.pq to check for incremental options
// 5. Use TableRelationships.pq to see dependencies
```

### Example 4: Troubleshooting Query Failures

```powerquery
// Query fails with "column not found" error
// 1. Use TableColumns.pq to verify column exists and exact spelling
// 2. Check data_type to ensure proper type handling
// 3. Verify table_name is correct (case-sensitive)
```

---

## Integration with Raw Table Documentation

These metadata queries complement our documented raw tables:

| Metadata Query | Raw Table Docs Section |
|----------------|------------------------|
| TimestampColumns | Incremental Refresh Reference in RAW-TABLES-SUMMARY.md |
| TableRelationships | Table Relationships Map in RAW-TABLES-SUMMARY.md |
| TableStats | Quick Stats Summary in RAW-TABLES-SUMMARY.md |
| TableColumns | Key Field Index in RAW-TABLES-SUMMARY.md |

**Workflow**:
1. ✅ Use metadata queries to **discover** what exists in source
2. ✅ Use RAW-TABLES-SUMMARY.md to **lookup** what we've documented
3. ✅ Use individual `.pq` files for **complete documentation** on specific tables

---

## Maintenance Notes

### When Source Schema Changes:
1. ✅ Run TableColumns.pq to detect new/changed columns
2. ✅ Run TableRelationships.pq to detect new relationships
3. ✅ Update affected `.pq` documentation files
4. ✅ Update RAW-TABLES-SUMMARY.md if field locations change

### Adding New Tables:
1. ✅ Run TableStats.pq to get row count
2. ✅ Run TableColumns.pq to see schema
3. ✅ Run TimestampColumns.pq to check incremental options
4. ✅ Run Indexes.pq to understand primary keys
5. ✅ Create new `.pq` file in `raw-tables/` directory
6. ✅ Add to RAW-TABLES-SUMMARY.md

---

## Technical Notes

### SQL Anywhere System Tables Used:
- `sys.systable` - Table metadata
- `sys.systabcol` - Column metadata
- `sys.sysidx` - Index metadata
- `sys.sysidxcol` - Index-column mappings
- `sys.sysforeignkey` - Foreign key relationships
- `sys.sysfkcol` - Foreign key column mappings

### Creator Filtering:
- `creator NOT IN (1, 3)` excludes system tables
- `1` = SYS (system owner)
- `3` = dbo system tables
- User tables typically have `creator > 3`

### Performance:
- All queries read from system catalog (fast)
- Safe to run frequently for troubleshooting
- No impact on production data

---

**See Also**:
- [RAW-TABLES-SUMMARY.md](../queries/RAW-TABLES-SUMMARY.md) - Quick reference for documented tables
- [REFRESH-TIMES.md](../queries/REFRESH-TIMES.md) - Performance tracking
- Individual table documentation in `queries/raw-tables/*.pq`

---

*These queries power the "Table-Column-Names-Search" Power BI report*
