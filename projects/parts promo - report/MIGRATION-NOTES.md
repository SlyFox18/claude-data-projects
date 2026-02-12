# Parts Promo Report - Migration Notes

**Date Started:** 01/16/2026
**Status:** In Progress
**Migration From:** Old Lakehouse (direct ODBC)
**Migration To:** New Lakehouse structure (InTrans_Incremental)

---

## 📊 Report Overview

**Report Name:** Parts Promo
**Department:** Parts
**Business Purpose:** Track promotional parts sales and analyze discount effectiveness

**Key Business Questions:**
- What is the total promotional discount given?
- How do promo sales compare to original sales values?
- What is the margin impact of promotions?
- Which branches/customers use promos most?
- Rolling 12-month trends vs previous year

---

## 🔄 Migration Summary

### **What Changed:**

| Component | Old Report | New Report |
|-----------|-----------|------------|
| **Data Source** | Direct ODBC to InTrans | Lakehouse InTrans_Incremental |
| **Refresh Strategy** | Full refresh | Leverages incremental source |
| **Date Tables** | 3 separate tables (Date, DateTable, DateTable1) | Single dim_DateTable |
| **Branch Dimension** | Dim_Branch | dim_BranchLocation (shared) |
| **Customer Dimension** | Base_Customer_Info | [To determine] |
| **Calculated Metrics** | DAX measures | Pre-calculated in Power Query |

### **Tables Created:**

| New Table | Purpose | Estimated Rows | Source |
|-----------|---------|----------------|--------|
| Fact_PartsPromo | Main promo transactions | ~50-100K | InTrans_Incremental |
| Fact_InTrans_AllPromo | All transactions for context | ~1-2M | InTrans_Incremental |

### **Tables Removed/Consolidated:**

- ❌ DateAutoTemplate → Use dim_DateTable
- ❌ DateTable, DateTable1 → Use dim_DateTable
- ❌ CalculatedTable → Metrics pre-calculated in Fact_PartsPromo
- ❌ MonthlySalesTable → Can be done with dim_DateTable time intelligence

---

## 📋 Pre-Calculated Columns in Fact_PartsPromo

These columns replace DAX calculated columns/measures:

| Column | Calculation | Replaces |
|--------|-------------|----------|
| NetSalesValue | PartSales + SaleValue | [Net Sales Value] DAX |
| DiscountAmount | ABS(SaleValue) | - |
| DiscountPercent | DiscountAmount / PartSales | [Discount %] DAX |
| OriginalMargin | PartSales - PartCost | [Original Margin $] DAX |
| NetMargin | NetSalesValue - PartCost | [Net Margin $] DAX |

---

## 🧮 DAX Measures Migration

### **Simplified Measures (Now SUM of columns):**

```dax
// Before: Complex calculations
// After: Simple aggregations

Discount = SUM(Fact_PartsPromo[DiscountAmount])

Net Sales Value = SUM(Fact_PartsPromo[NetSalesValue])

Original Sale Value = SUM(Fact_PartsPromo[PartSales])

Cost Value = SUM(Fact_PartsPromo[PartCost])

Original Margin $ = SUM(Fact_PartsPromo[OriginalMargin])

Net Margin $ = SUM(Fact_PartsPromo[NetMargin])

Discount % = DIVIDE(
    SUM(Fact_PartsPromo[DiscountAmount]),
    SUM(Fact_PartsPromo[PartSales]),
    0
)

Original Margin % = DIVIDE(
    [Original Margin $],
    [Original Sale Value],
    0
)

Net Margin % = DIVIDE(
    [Net Margin $],
    [Net Sales Value],
    0
)
```

### **Measures Still Needed (Rolling Calculations):**

```dax
// Rolling 12 Month calculations - keep similar logic
Rolling12MonthCount =
CALCULATE(
    COUNTROWS(Fact_PartsPromo),
    DATESINPERIOD(dim_DateTable[Date], TODAY(), -12, MONTH)
)

Rolling12MonthNetSalesValue =
CALCULATE(
    SUM(Fact_PartsPromo[NetSalesValue]),
    DATESINPERIOD(dim_DateTable[Date], TODAY(), -12, MONTH)
)

// Previous Year Rolling - use SAMEPERIODLASTYEAR with dim_DateTable
PreviousYearRollingCount =
CALCULATE(
    [Rolling12MonthCount],
    SAMEPERIODLASTYEAR(dim_DateTable[Date])
)

// Percent Changes
PercentChangeRolling =
DIVIDE(
    [Rolling12MonthCount] - [PreviousYearRollingCount],
    [PreviousYearRollingCount],
    0
)
```

### **Measures to Preserve As-Is:**

- All HTML Tooltip measures (6 measures)
- Color Discount % (formatting)
- Greeting / User (display)
- ShowRow / SelectedMinRow / SelectedMaxRow (pagination)

---

## 🔗 Relationships

### **New Model Relationships:**

```
dim_DateTable ──────────────┐
                            ├──> Fact_PartsPromo
dim_BranchLocation ─────────┘

dim_DateTable ──────────────┐
                            ├──> Fact_InTrans_AllPromo
dim_BranchLocation ─────────┘

Fact_PartsPromo[REF_NO] ←→ Fact_InTrans_AllPromo[REF_NO]
(Many-to-Many via bridge or TREATAS)
```

### **Relationship Changes:**

| Old | New | Notes |
|-----|-----|-------|
| Parts_Promo[BRANCH] → Dim_Branch[BranchID] | Fact_PartsPromo[BranchKey] → dim_BranchLocation[BranchID] | Use shared dim |
| Parts_Promo[Trans_Datetime] → Date[Date] | Fact_PartsPromo[DateKey] → dim_DateTable[Date] | Use shared dim |
| Parts_Promo[customer_no] → Base_Customer_Info[Account] | [TBD - may use dim_CustomerList] | Investigate |

---

## ⚠️ Open Questions

1. **Customer Dimension:**
   - Old report uses Base_Customer_Info
   - Should we use an existing dimension or create project-specific?
   - Check if dim_CustomerList fits this use case

2. **Many-to-Many Relationship:**
   - REF_NO links Fact_PartsPromo to Fact_InTrans_AllPromo
   - Consider bridge table for cleaner design
   - Or use TREATAS pattern in DAX

3. **Pagination Table:**
   - Old report has Pagnation Table for visual pagination
   - Is this still needed? Or replace with Power BI pagination features?

4. **MeasureSelector:**
   - DATATABLE with "Promo Count" and "Net Sales"
   - May need to recreate or use Field Parameters

---

## 📝 Testing Checklist

### **Before Deployment:**

- [ ] Update Lakehouse workspace/lakehouse IDs in queries
- [ ] Create dataflows in Fabric
- [ ] Test refresh times
- [ ] Validate row counts against old report
- [ ] Compare key metrics (Total Net Sales, Discount amounts)
- [ ] Verify relationships work correctly
- [ ] Test all DAX measures
- [ ] Test HTML tooltips render correctly

### **Validation Queries:**

```sql
-- Row count comparison
-- Old: SELECT COUNT(*) FROM Parts_Promo (old report)
-- New: SELECT COUNT(*) FROM Fact_PartsPromo

-- Total Net Sales comparison
-- Old: SUM of Net Sales Value measure
-- New: SUM(Fact_PartsPromo[NetSalesValue])

-- Promo Count by Branch
-- Compare old vs new for consistency
```

---

## 📅 Migration Steps

1. [x] Analyze old report structure
2. [x] Create migration plan
3. [x] Create Fact_PartsPromo.pq
4. [x] Create Fact_InTrans_AllPromo.pq
5. [ ] Update Lakehouse IDs in queries
6. [ ] Create dataflows in Fabric
7. [ ] Test refresh and validate
8. [ ] Create new semantic model
9. [ ] Recreate DAX measures
10. [ ] Recreate report visuals
11. [ ] Test and compare with old report
12. [ ] Document with /document-project
13. [ ] Update FACT-TABLES-SUMMARY.md

---

## 📚 References

- Old queries: `queries/old report/fact tables/`
- Old model exports: `info-exports/old report/`
- New queries: `queries/new report/fact tables/`
- Shared dimensions: `.claude/queries/dimensions/`
- Source data: InTrans_Incremental (10.2M rows, 3x daily)
