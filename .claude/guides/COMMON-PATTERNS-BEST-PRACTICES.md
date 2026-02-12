# Common Patterns & Best Practices

**Purpose:** Repeatable patterns and best practices for Power BI/Fabric development
**Last Updated:** 2026-01-15

---

## 📚 Table of Contents

1. [Power Query Patterns](#power-query-patterns)
2. [Incremental Refresh Strategies](#incremental-refresh-strategies)
3. [Data Modeling Best Practices](#data-modeling-best-practices)
4. [DAX Patterns](#dax-patterns)
5. [Performance Optimization](#performance-optimization)
6. [Naming Conventions](#naming-conventions)
7. [Testing & Validation](#testing--validation)

---

## 🔄 Power Query Patterns

### **Pattern 1: Watermark-Based Incremental Refresh** ⭐ GOLD STANDARD

**When to Use:**
- Large transactional tables (1M+ rows)cp, trigger a refresh of the Parts Promo dataflow"
- Frequent refreshes needed (multiple times daily)
- Has datetime column for filtering

**Example:** Raw_InTrans_Incremental (10.2M rows, 2-3 min refresh)

**Implementation:**

```powerquery
let
    // Get watermark from helper query
    WatermarkValue = if Value.Is(GetWatermark, type table)
                     then GetWatermark{0}[LastLoadedDatetime]
                     else GetWatermark,

    // Convert to SQL-friendly format
    WatermarkText = DateTime.ToText(WatermarkValue, "yyyy-MM-dd HH:mm:ss"),

    // Build SQL query with watermark filter
    SQL = "SELECT * FROM SourceTable
           WHERE ModifiedDate > '" & WatermarkText & "'",

    Source = Odbc.Query("dsn=ConnectionString", SQL),

    // CRITICAL: Duplicate protection on primary key
    RemoveDuplicates = Table.Distinct(Source, {"PrimaryKeyColumn"})
in
    RemoveDuplicates
```

**GetWatermark Helper Query:**
```powerquery
let
    Source = #table(
        type table [LastLoadedDatetime = datetime],
        {{#datetime(2026, 1, 15, 0, 0, 0)}}
    )
in
    Source
```

**Benefits:**
- 90%+ time savings vs full refresh
- Enables multiple daily refreshes
- Self-healing on failures
- Scales to 10M+ rows

---

### **Pattern 2: Self-Updating Dimension**

**When to Use:**
- Reference data that changes infrequently
- Extract distinct values from larger table

**Example:** dim_VendorCode, dim_SLC, dim_Source

**Implementation:**

```powerquery
let
    // Source data
    Source = Lakehouse.Contents()[...],

    // Select only needed column
    SelectColumn = Table.SelectColumns(Source, {"ColumnName"}),

    // Get distinct values
    RemoveDuplicates = Table.Distinct(SelectColumn),

    // Remove blanks
    RemoveBlanks = Table.SelectRows(RemoveDuplicates,
        each not List.IsEmpty(
            List.RemoveMatchingItems(
                Record.FieldValues(_), {"", null}
            )
        )
    ),

    // Sort for consistency
    SortRows = Table.Sort(RemoveBlanks, {{"ColumnName", Order.Ascending}}),

    // Add surrogate key
    AddKey = Table.AddIndexColumn(SortRows, "ColumnNameKey", 1, 1, Int64.Type),

    // Reorder columns (key first)
    ReorderColumns = Table.ReorderColumns(AddKey, {"ColumnNameKey", "ColumnName"})
in
    ReorderColumns
```

---

### **Pattern 3: Unknown Record Pattern**

**When to Use:**
- Handle missing dimension values gracefully
- Prevent broken relationships

**Implementation:**

```powerquery
// Create Unknown record helper query
let
    UnknownRecord = #table(
        type table [DimensionKey = Int64.Type, DimensionCode = text],
        {{-1, "UNKNOWN"}}
    )
in
    UnknownRecord

// In main dimension query, append Unknown
let
    MainDimension = [...your dimension logic...],

    // Append Unknown record
    AppendUnknown = Table.Combine({MainDimension, UnknownDimension}),

    // Sort to put Unknown at top
    SortRows = Table.Sort(AppendUnknown, {{"DimensionKey", Order.Ascending}})
in
    SortRows
```

**Used In:**
- dim_SLC (SLCKey = -1)
- dim_Source (SourceKey = -1)
- dim_CommodityCode (CommodityCodeKey = -1)

---

### **Pattern 4: Early Filtering for Performance**

**When to Use:**
- Always! Filter as early as possible

**Bad Example:**
```powerquery
let
    Source = Sql.Database("server", "db"),
    AllData = Source{[Schema="dbo",Item="LargeTable"]}[Data],
    // Transforms on millions of rows
    FilteredData = Table.SelectRows(AllData, each [Date] >= #date(2024,1,1))
in
    FilteredData
```

**Good Example:**
```powerquery
let
    // Filter in SQL query (query folding)
    SQL = "SELECT * FROM LargeTable
           WHERE Date >= '2024-01-01'",
    Source = Odbc.Query("dsn=Connection", SQL)
in
    Source
```

---

### **Pattern 5: Strategic Column Selection**

**When to Use:**
- Source has many columns but you need few
- Reduce memory footprint and transfer time

**Example:** InHist_PmManage (22 of 62 columns selected = 65% reduction)

```powerquery
let
    // Select only needed columns in SQL query
    SQL = "SELECT
        Column1,
        Column2,
        Column3
    FROM SourceTable
    WHERE [filter conditions]",

    Source = Odbc.Query("dsn=Connection", SQL)
in
    Source
```

**NOT this:**
```powerquery
let
    Source = Sql.Database("server", "db"),
    AllColumns = Source{[Item="Table"]}[Data],
    SelectColumns = Table.SelectColumns(AllColumns, {"Column1", "Column2", "Column3"})
in
    SelectColumns
```

---

## ⚡ Incremental Refresh Strategies

### **Strategy Matrix:**

| Data Size | Change Frequency | Recommended Strategy | Example |
|-----------|------------------|---------------------|---------|
| <100K rows | Any | Full refresh | dim_BranchLocation |
| 100K-1M rows | Daily | ModifiedDate filter with 2-year scope | WKROFILE |
| 1M-10M rows | Multiple times daily | Watermark-based incremental | InTrans_Incremental |
| 10M+ rows | Any | Watermark + Partitioning | Future large datasets |

---

### **Date-Based Incremental Refresh (Fabric Native)**

**When to Use:**
- Table has date/datetime column
- Can define date range parameters
- Want Fabric to manage partitions automatically

**Implementation:**

```powerquery
let
    // Define parameters (Fabric will manage these)
    RangeStart = #date(2024, 1, 1),
    RangeEnd = #date(2026, 12, 31),

    // Filter using parameters
    SQL = "SELECT * FROM SourceTable
           WHERE TransDate >= '" & Date.ToText(RangeStart) & "'
             AND TransDate <= '" & Date.ToText(RangeEnd) & "'",

    Source = Odbc.Query("dsn=Connection", SQL)
in
    Source
```

**In Fabric:**
- Configure incremental refresh policy
- Set refresh range (e.g., last 2 years)
- Set archive range (e.g., data older than 2 years)

---

## 🗂️ Data Modeling Best Practices

### **Star Schema Design:**

```
        dim_Date
           |
           |
        dim_Branch ──> Fact_Table <── dim_Parts
           |               |
           |               |
        dim_Customer   dim_Product
```

**Rules:**
1. **One fact grain**: Clearly define what one row represents
2. **Surrog keys**: Use integer surrogate keys for relationships
3. **Dimension denormalization**: Flatten dimensions for performance
4. **Date table required**: Always have a date dimension
5. **No many-to-many**: Avoid or use bridge tables

---

### **Relationship Best Practices:**

**Good:**
```
Fact[DateKey] → dim_Date[DateKey] (Many-to-One, Single direction)
Fact[BranchKey] → dim_Branch[BranchKey] (Many-to-One, Single direction)
```

**Avoid:**
```
Fact ←→ Dimension (Bi-directional - rarely needed, causes ambiguity)
Dimension ←→ Dimension (Many-to-many - use bridge table)
```

---

### **Dimension Types:**

**Type 0 - Static (Hard-coded)**
- Example: dim_AdjustmentType (7 fixed adjustment types)
- Never changes, no refresh needed
- Use in-memory tables

**Type 1 - Overwrite (Current state only)**
- Example: dim_Parts (current part info, no history)
- Most common type
- Simple, performant

**Type 2 - Historical tracking (SCD)**
- Example: Would track price changes over time
- Not currently used (added complexity)
- Only if business requires history

---

## 📊 DAX Patterns

### **Pattern 1: Basic Measure with VAR**

**Always use variables for:**
- Readability
- Performance (calculation done once)
- Debugging (test variable values)

**Good:**
```dax
Total Revenue =
VAR SalesAmount = SUM(Fact_Sales[Revenue])
VAR TaxAmount = SUM(Fact_Sales[Tax])
RETURN
    SalesAmount + TaxAmount
```

**Bad:**
```dax
Total Revenue = SUM(Fact_Sales[Revenue]) + SUM(Fact_Sales[Tax])
```

---

### **Pattern 2: Time Intelligence**

**Use dim_DateTable for time calculations:**

```dax
Sales YTD =
CALCULATE(
    [Total Sales],
    DATESYTD(dim_DateTable[Date])
)

Sales Previous Year =
CALCULATE(
    [Total Sales],
    SAMEPERIODLASTYEAR(dim_DateTable[Date])
)

Sales vs Last Year =
VAR CurrentSales = [Total Sales]
VAR PreviousSales = [Sales Previous Year]
RETURN
    DIVIDE(
        CurrentSales - PreviousSales,
        PreviousSales,
        0
    )
```

---

### **Pattern 3: CALCULATE Patterns**

**Multiple filters:**
```dax
Branch 12 Sales =
CALCULATE(
    [Total Sales],
    dim_Branch[BranchID] = 12,
    dim_DateTable[Year] = 2025
)
```

**Remove filters:**
```dax
Percent of Total =
DIVIDE(
    [Total Sales],
    CALCULATE([Total Sales], ALL(dim_Product)),
    0
)
```

**Change filter context:**
```dax
Previous Month Sales =
CALCULATE(
    [Total Sales],
    DATEADD(dim_DateTable[Date], -1, MONTH)
)
```

---

### **Pattern 4: SWITCH for Conditional Logic**

**Better than nested IFs:**

```dax
Performance Category =
VAR FillRate = [First Pass Fill Rate]
RETURN
    SWITCH(
        TRUE(),
        FillRate >= 0.95, "Excellent",
        FillRate >= 0.90, "Good",
        FillRate >= 0.85, "Fair",
        "Needs Improvement"
    )
```

---

### **Pattern 5: DIVIDE for Safe Division**

**Always use DIVIDE (not /)**

```dax
Margin Percent =
DIVIDE(
    [Revenue] - [Cost],
    [Revenue],
    0  // Return 0 if denominator is 0 or BLANK
)
```

---

## ⚡ Performance Optimization

### **Power Query Optimization:**

1. **Query Folding** - Let database do the work
   - Use native SQL queries when possible
   - Check query folding in View → Query Dependencies

2. **Reduce Data Early**
   - Filter rows early
   - Select only needed columns
   - Remove duplicates early

3. **Data Types**
   - Use smallest appropriate data type
   - Int32 vs Int64 (Int32 uses less memory)
   - Decimal vs Currency

4. **Avoid Calculated Columns**
   - Do transformations in Power Query, not DAX
   - Calculated columns stored in memory
   - Measures calculated on-demand

---

### **DAX Optimization:**

1. **Use Variables**
   - Calculated once, reused
   - Easier to debug

2. **Avoid Row Context**
   - Iterators (SUMX, FILTER) slower than aggregates
   - Use SUM, COUNT when possible

3. **Reduce Cardinality**
   - Relationships on lower cardinality columns perform better
   - Integer keys faster than text keys

4. **Avoid Bi-directional Relationships**
   - Causes ambiguity
   - Hurts performance
   - Only use when absolutely necessary

---

### **Model Optimization:**

1. **Star Schema** - Not snowflake
2. **Integer Keys** - Not text or composite keys
3. **Remove Unused Columns** - Reduce model size
4. **Aggregations** - For large fact tables
5. **Incremental Refresh** - For large historical data

---

## 📝 Naming Conventions

### **Tables:**

- **Facts:** `Fact_[BusinessEntity]` (e.g., Fact_PartsInventory)
- **Dimensions:** `dim_[BusinessEntity]` (e.g., dim_BranchLocation)
- **Raw:** `Raw_[SourceTable]` (e.g., Raw_InTrans_Incremental)

### **Columns:**

- **PascalCase:** `ColumnName`, `TransactionDate`, `SaleValue`
- **Keys:** `[Entity]Key` (e.g., DateKey, BranchKey, PartKey)
- **Descriptive:** Avoid abbreviations unless standard

### **Measures:**

- **Descriptive Names:** `Total Revenue`, `Average Margin %`
- **Group in Display Folders:** Organize by category
- **Units Clear:** `Revenue $`, `Margin %`, `Count #`

### **Dataflows:**

- **Prefix by Type:**
  - `df_[TableName]_Raw` (e.g., df_InTrans_Incremental)
  - `df_Dim_[Name]` (e.g., df_Dim_BranchLocation)
  - `df_Fact_[Name]` (e.g., df_Fact_PartsInventory)

---

## 🧪 Testing & Validation

### **Automated Validation Queries:**

**1. Row Count Validation:**
```sql
SELECT COUNT(*) as RowCount
FROM Fact_TableName
WHERE Date >= DATEADD(day, -7, GETDATE())
-- Should be approximately [expected range]
```

**2. Duplicate Detection:**
```sql
SELECT [GrainColumn1], [GrainColumn2], COUNT(*) as Duplicates
FROM Fact_TableName
GROUP BY [GrainColumn1], [GrainColumn2]
HAVING COUNT(*) > 1
-- Should return 0 rows
```

**3. Null Checks:**
```sql
SELECT COUNT(*) as NullCount
FROM Fact_TableName
WHERE [CriticalColumn] IS NULL
-- Should return 0 for critical columns
```

**4. Referential Integrity:**
```sql
SELECT COUNT(*) as OrphanedRecords
FROM Fact_TableName f
LEFT JOIN dim_Dimension d ON f.DimensionKey = d.DimensionKey
WHERE d.DimensionKey IS NULL
-- Should return 0 or use Unknown key (-1)
```

**5. Business Rule Validation:**
```sql
SELECT COUNT(*) as ViolationCount
FROM Fact_TableName
WHERE [BusinessRule conditions]
-- Example: Revenue should never be negative
WHERE Revenue < 0
```

---

### **Pre-Deployment Checklist:**

- [ ] Query documented with header comments
- [ ] Grain clearly defined
- [ ] Primary key identified
- [ ] Relationships defined
- [ ] Naming conventions followed
- [ ] Performance tested
- [ ] Validation queries created
- [ ] Refresh schedule defined
- [ ] Dependencies documented
- [ ] Project README updated

---

## 🎯 Quick Reference Cards

### **When to Use What Refresh Strategy:**

| Situation | Strategy | Example |
|-----------|----------|---------|
| Small table, rarely changes | On-demand | dim_AdjustmentType |
| Reference data, monthly changes | Monthly full refresh | dim_VendorCode |
| Daily changes, <1M rows | Daily full refresh | WKROFILE |
| Daily changes, 1M-10M rows | Watermark incremental | InTrans_Incremental |
| Multiple daily changes | Watermark + dedicated pipeline | InTrans (3x daily) |

---

### **Performance Troubleshooting:**

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| Slow refresh (sudden) | Pipeline contention | Time-shift refresh |
| Slow refresh (gradual) | Data growth | Implement incremental refresh |
| Slow report load | Too many visuals | Reduce visuals, add aggregations |
| Slow report load | Bad DAX | Optimize measures, use variables |
| High memory usage | Calculated columns | Move to Power Query |
| High memory usage | High cardinality | Use integer keys, reduce columns |

---

## 📚 Pattern Library Index

All documented patterns with references:

1. **Watermark Incremental Refresh** - See: Raw_InTrans_Incremental.pq
2. **Self-Updating Dimension** - See: dim_VendorCode.pq, dim_SLC.pq
3. **Unknown Record Pattern** - See: dim_SLC.pq, dim_Source.pq
4. **Multiple Display Names** - See: dim_Technician_Code_Names.pq
5. **Dual-Source Integration** - See: dim_Vehicle.pq
6. **Service Intelligence Scoring** - See: dim_Vehicle.pq
7. **Dual-Fact Architecture** - See: dim_UniqueCustomers.pq
8. **Strategic Column Selection** - See: Raw_InHist_PmManage.pq
9. **Date-Based Incremental** - See: Multiple raw tables with ModifiedDate
10. **Pre-Aggregated Context Dimension** - See: dim_RepairOrder.pq (Parts Promo)
11. **Transaction-Derived Dimension** - See: dim_PromoType.pq (Parts Promo)
12. **Safe Qty Conversion** - See: Fact_InTrans_AllPromo_ForReport.pq

---

## ⚠️ Common Pitfalls (Learned from Parts Promo)

### **Pitfall 1: ZP Franchise Filter**

In InTrans, promo parts (starting with *) typically have Franchise = 'ZP'. Don't filter these out!

```powerquery
// WRONG - excludes all promos
and [Franchise] <> "ZP"

// CORRECT - don't filter franchise for promo parts
// (no franchise filter)
```

### **Pitfall 2: Branch Column is Text**

Branch codes can include sub-branches: 4B, 4S, 4I (all branch 4 variations).

```powerquery
// WRONG
{"Branch", Int64.Type}  // Fails on "4B"

// CORRECT
{"Branch", type text}
```

### **Pitfall 3: Date vs DateTime Comparison**

When filtering datetime columns, use `#datetime()` not `#date()`.

```powerquery
// WRONG
StartDate = #date(2022, 1, 1)

// CORRECT
StartDate = #datetime(2022, 1, 1, 0, 0, 0)
```

### **Pitfall 4: Description Column Content**

In InTrans, the Description column often contains **customer name**, not part description. Use jdis_Part_Information for actual part descriptions.

---

**Remember:** These patterns are proven in production. Use them as templates for new development!
