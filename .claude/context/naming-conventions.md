# Naming Conventions and Standards

## Overview

Consistent naming conventions across all dataflows, tables, dimensions, facts, and reports.

---

## Dataflow Naming

**Pattern:** `df_Name_Type`

### Examples:

**Raw Data Ingestion:**
- `df_InMaster_Raw`
- `df_jdis_Part_Information_Raw`
- `df_vhstock_Raw`

**Dimensions:**
- `df_Dim_Location`
- `df_Dim_Parts`
- `df_Dim_CustomerList`

**Facts:**
- `df_Fact_PartsAdjustment`
- `df_Fact_LaborJobs`
- `df_Fact_Inspection1`

### Naming Rules:
- Always start with `df_` prefix
- Use PascalCase for name components
- Include type suffix: `_Raw`, `_Dim`, `_Fact`
- Be descriptive but concise
- Avoid abbreviations unless well-known (e.g., Dim, Fact)

---

## Lakehouse Table Naming

### Raw Tables

**Pattern:** Use original source system name

**Examples:**
- `jdis_Part_Information` (from source)
- `InMaster` (from source)
- `vhstock` (from source)
- `Fact_InTrans` (from source)

**Rules:**
- Keep exact source system name
- Maintains traceability
- No transformation of name
- Case-sensitive preservation

### Dimension Tables

**Pattern:** `dim_TableName`

**Examples:**
- `dim_BranchLocation`
- `dim_DateTable`
- `dim_Parts`
- `dim_CustomerList`
- `dim_Parts_LowMargin` (specialized dimension)

**Rules:**
- Always start with `dim_` prefix (lowercase)
- Use PascalCase for TableName
- Singular form preferred (dim_Part not dim_Parts - though existing may vary)
- Descriptive but concise
- Indicate specialization if needed (e.g., `_LowMargin`)

### Fact Tables

**Pattern:** `Fact_TableName`

**Examples:**
- `Fact_PartsAdjustment`
- `Fact_LaborJobs`
- `Fact_InTrans` (if created as fact, though source uses this name)

**Rules:**
- Always start with `Fact_` prefix (capitalized)
- Use PascalCase for TableName
- Descriptive of transaction/event type
- Singular form preferred

---

## Column Naming

### General Rules:
- PascalCase for all column names
- No spaces (unless from source system)
- Descriptive but concise
- Consistent across tables when possible

### Common Patterns:

**Keys:**
- `PartNumber`
- `Branch`
- `Franchise`
- `AccountNumber`
- `CustomerKey`
- `DateKey`

**Descriptive Fields:**
- `PartDescription`
- `BranchName`
- `CustomerName`

**Measures/Calculations:**
- `OnHandQty`
- `SellPrice1`
- `Cost`
- `StockOrderPrice`
- `InventoryCost`

**Flags:**
- `LowMarginFlag`
- `IsActive`
- `HasStock`

**Dates:**
- `TransactionDate`
- `OrderDate`
- `InvoiceDate`

---

## DAX Measure Naming

### Pattern Depends on Scope:

**Simple Measures:**
```dax
Total Sales
Quantity
Average Price
```

**Calculated Measures:**
```dax
Positive Margin $ Discrepancy
Negative Margin $ Discrepancy
Total Parts with Discrepancy
```

**KPI Measures:**
```dax
KPI: Total Revenue
KPI: Margin %
```

**Helper Measures (prefix with underscore):**
```dax
_SellValue
_CostValue
_MarginDiscrepancy
```

### Rules:
- Clear, business-friendly names
- Spaces allowed for readability
- Use $ for currency measures
- Use % for percentage measures
- Prefix internal/helper measures with underscore
- Avoid abbreviations unless industry-standard

---

## DAX Column Naming (Calculated Columns)

### Pattern: Same as regular columns

**Examples:**
- `MarginDifference`
- `LowMarginFlag`
- `IsDiscrepancy`

### Rules:
- PascalCase
- Descriptive
- Distinguish from measures (no spaces, usually)
- Avoid prefixes unless needed for clarity

---

## Report Naming

### Power BI Desktop Files (.pbix)

**Pattern:** `[Department] - [Report Name].pbix`

**Examples:**
- `Parts - Low Margin Sales.pbix`
- `Service - Inspection Report.pbix`
- `Financial - Revenue Analysis.pbix`

### Rules:
- Department first
- Descriptive report name
- Spaces allowed
- Consistent with folder names

---

## Folder Naming (Project Structure)

**Pattern:** `[report name with spaces]/`

**Examples:**
```
projects/
├── part sales with low margin/
├── price matrix - report/
├── inspection report/
└── labor jobs analysis/
```

### Rules:
- Lowercase with spaces
- Matches report purpose
- Hyphens for separators if needed
- Keep URL-friendly if possible

---

## Documentation File Naming

### Pattern Depends on Document Type:

**Main Documentation:**
- `README.md` (master entry point)
- `PROJECT-SUMMARY.md`
- `QUICK-START.md`

**Implementation Guides:**
- `SETUP-GUIDE.md`
- `MEASURE-REFERENCE.md`

**Fix Documentation:**
- `KPI-Measures-Fix.md`
- `Calculated-Columns-Fix.md`
- `Page-2-Dimension-Fix.md`

**Discovery Documentation:**
- `Row-Count-Inflation.md`
- `Old-Report-Bug-Found.md`
- `Cost-vs-StockOrderPrice.md`

### Rules:
- UPPERCASE for section words
- Hyphens for separators
- `.md` extension
- Descriptive of content
- Group by type in folders

---

## Query Naming (Power Query / M)

### In Semantic Model:

**Dimension Queries:**
- `dim_BranchLocation`
- `dim_DateTable`
- `dim_Parts_LowMargin`

**Fact Queries:**
- `Fact_InTrans`
- `Fact_PartsAdjustment`

**Helper Queries (prefix with underscore):**
- `_Parameters`
- `_DateRanges`
- `_FilterHelper`

### Rules:
- Match Lakehouse table names when loading from Lakehouse
- Use underscore prefix for queries not loaded to model
- Group related queries in Power Query editor

---

## Workspace Naming

**Pattern:** Department or function-based

**Examples:**
- `LH_Master_Data` (master data workspace)
- `Parts Department` (department workspace)
- `Service Department`
- `Financial Department`

### Rules:
- Clear purpose
- Department name if report-specific
- Master/shared workspace clearly identified

---

## Key Takeaways

### Be Consistent
- Same pattern across all similar objects
- Makes discovery easier
- Reduces cognitive load

### Be Descriptive
- Names should explain purpose
- Avoid cryptic abbreviations
- Think of future maintainers

### Use Prefixes
- `df_` for dataflows
- `dim_` for dimensions
- `Fact_` for facts
- `_` for internal/helper objects

### Follow Existing Patterns
- When adding to existing project, match established names
- Don't mix naming conventions
- Document deviations if necessary

---

## Examples in Context

### Complete Example: Parts Dimension

**Source Table:** `jdis_Part_Information`
**Raw Dataflow:** `df_jdis_Part_Information_Raw`
**Dimension Dataflow:** `df_Dim_Parts`
**Dimension Table:** `dim_Parts`
**Key Columns:** `PartNumber`, `Branch`, `Franchise`, `PartDescription`, `SellPrice1`, `Cost`

### Complete Example: Sales Fact

**Source Tables:** `InMaster`, `jdis_Part_Movement`
**Fact Dataflow:** `df_Fact_PartsSales`
**Fact Table:** `Fact_PartsSales`
**Key Columns:** `PartNumber`, `Branch`, `Franchise`, `TransactionDate`, `Quantity`, `SalesAmount`
**Related Dimension:** `dim_Parts`, `dim_BranchLocation`, `dim_DateTable`

---

**Last Updated:** January 2026
**Maintained By:** User + Claude
**Version:** 1.0
