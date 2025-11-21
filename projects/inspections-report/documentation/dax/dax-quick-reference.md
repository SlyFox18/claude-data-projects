# DAX Measures - Quick Reference Guide

**Essential measures for daily report usage and troubleshooting.**

For complete documentation of all 172 measures, see `dax-measures-library.md`.

---

## 📊 Core Metrics (The Big 4)

### Total Inspections
Count all inspection job codes | Used On: Pages 1, 2, 3

```dax
Total Inspections = 
CALCULATE(
    COUNTROWS(Fact_LaborJobSummary),  
    Fact_LaborJobSummary[IsInspection] = TRUE
)
```

### Inspection $$
Revenue from inspection job codes only | Used On: Pages 1, 2, 3

```dax
Inspection $$ = 
CALCULATE(
    SUM(Fact_LaborJobSummary[TotalInvoicedAmount]),
    Fact_LaborJobSummary[IsInspection] = TRUE
)
```

### Labor $$
Revenue from additional services (non-inspection labor) | Used On: Pages 1, 2

```dax
Labor $$ = [Labor With Inspection] - [Inspection $$]
```

### Parts $ Total
Total parts revenue on inspection work orders | Used On: Pages 1, 2

```dax
Parts $ Total = 
CALCULATE(
    SUM(Fact_WorkOrderParts[SaleValue]),
    Fact_WorkOrderParts[InvoiceNumber] IN VALUES(ValidInvoiceNumbers[InvoiceNumber]),
    Fact_WorkOrderParts[Franchise] <> "ZP",
    NOT(Fact_WorkOrderParts[PartNumber] IN {"ADV", "LEGACY", "4900", "*10PROMO"})
)
```

---

## 🎯 Goal Tracking

### % to Goal - Inspections
Performance percentage against inspection goal | Used On: Page 3

```dax
% to Goal - Inspections = 
DIVIDE([Total Inspections], [Total Inspection Goal], 0)
```

**Color Coding:** 🟢 ≥100% | 🟡 90-99% | 🔴 <90%

### Total Inspection Goal
Sum of inspection goals from external Excel file | Used On: Pages 1, 3

```dax
Total Inspection Goal = SUM('Inspection Goals'[Goal])
```

---

## ⏳ Pending Inspections

### Pending Inspections Count
Count of uninvoiced inspections | Used On: Page 4

```dax
Pending Inspections Count = COUNTROWS(Fact_PendingInspections)
```

### Average Pending Age
Average days since creation | Used On: Page 4

```dax
Average Pending Age = AVERAGE(Fact_PendingInspections[DaysSinceCreation])
```

---

## 💡 ServiceRecommendations

### Service Frequency %
How often service is added to specific inspection type | Used On: Page 5

```dax
Service Frequency % = 
VAR CompletedInspections = [Completed Inspections - Selected JobCode]
VAR ServicesAdded = [Service Count - For JobCode]
RETURN DIVIDE(ServicesAdded, CompletedInspections, 0)
```

---

## 📋 Work Order Details

### WO Grand Total
Total revenue for selected work order | Used On: Page 7

```dax
WO Grand Total = [WO Total Labor] + [WO Total Parts]
```

---

## 💰 Discount Analysis

### Total Discount $
Total discount amount applied | Used On: Page 2

```dax
Total Discount $ = 
[Parts Discount] + [Labor Discount by Job Code] + [Trucking Discount by Job Code]
```

---

## 🎨 HTML Visualization Measures

**Total:** 41 HTML measures create rich, styled visual components

**Key HTML Measures:**
- Hero Card HTML - Brand Colors (multiple versions)
- Revenue Breakdown Cards HTML
- CS690-CS770 Panel HTML
- Discount Panel HTML
- WO Details - Summary Cards

All HTML measures use inline CSS with gradients, brand colors, and dynamic content.

**Full HTML code:** See `dax-measures-library.md`

---

## 📐 Common DAX Patterns

### Basic Count with Filter
```dax
[Measure] = CALCULATE(COUNTROWS(Table), Table[Column] = Condition)
```

### Sum with Multiple Filters
```dax
[Measure] = CALCULATE(SUM(Table[Column]), Filter1, Filter2, NOT(Filter3))
```

### Division with BLANK Handling
```dax
[Measure] = DIVIDE([Numerator], [Denominator], 0)
```

### Context Transition
```dax
[Measure] = CALCULATE(SUM(Table[Column]), ALLEXCEPT(Table, Table[KeyColumn]))
```

---

## 🎯 Measure Usage by Page

- **Page 1 - Home:** Core metrics, goals, HTML hero cards
- **Page 2 - Details:** Averages by job code, discounts
- **Page 3 - Goals:** Goal tracking, performance %
- **Page 4 - Pending:** Queue metrics, aging analysis
- **Page 5 - Recommendations:** Service frequency, patterns
- **Page 6 - Work Order List:** WO totals, drill-through context
- **Page 7 - Work Order Details:** Line-by-line breakdown

---

## 🔍 Troubleshooting

**Measure Returns BLANK:**
- Check filter context
- Verify relationships
- Use DIVIDE() third parameter

**Incorrect Totals:**
- Check context transition (use CALCULATE)
- Review ALLEXCEPT() usage

**HTML Not Rendering:**
- Requires newer Power BI Desktop
- Use in correct visual type
- Check quote escaping

---

**Last Updated:** November 18, 2025  
**Quick Reference:** ~30 key measures  
**Full Library:** 172 measures in `dax-measures-library.md`