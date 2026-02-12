# Quick Start Guide

Get up and running with the Part Sales with Low Margin report in 5 minutes.

## 1. Open the Report

1. Navigate to: `reports/current/Part Sales with Low Margin.pbip`
2. Open in Power BI Desktop
3. Wait for data to load

## 2. Understand the Pages

### Page 1: Parts Sales with Low Margins
**Purpose:** Transaction-level margin analysis

**Key Features:**
- Filter by date range, branch, franchise, part number
- See actual vs. original margin for each transaction
- Identify patterns in margin discrepancies

**Main Visual:** Table showing all transactions with margin calculations

### Page 2: Inventory Cost Discrepancy
**Purpose:** Current inventory snapshot of margin gaps

**Key Features:**
- KPI cards showing total positive, negative, and net discrepancies
- Table of parts with margin issues
- Recommended new sell prices

**Main Visuals:**
- 3 KPI cards (Positive, Negative, Net Margin $ Discrepancy)
- Detailed table of parts requiring action

### Page 3: Low Action Items
**Purpose:** Prioritized list of parts needing pricing action

**Main Visual:** Filtered view of high-impact margin issues

## 3. Common Filters

**Branch Filter:**
- Located in top filter bar
- Select specific branch(es) or "All"
- Applies to all pages

**Franchise Filter:**
- Located in top filter bar
- Select D, C, S, or combinations
- **Note:** Page 2 excludes Franchise 'S' by default (operational requirement)

**Date Filter (Page 1 only):**
- Use the date slicer to select time period
- Defaults to last 12 months

**Margin % Filter (Page 2):**
- Slider to filter parts by margin percentage range
- Default: -50% to 100%

## 4. Key Metrics Explained

### Actual Margin $ / %
What the part actually sold for minus its cost (transaction-level)

### Original Margin $ / %
What the margin would have been at the original stock order price

### Margin $ Discrepancy
Difference between actual and original margin (transaction-level)

### Desired Margin $ / %
Target margin based on Cost field from inventory (Page 2 only)

### Positive/Negative/Net Margin $ Discrepancy (Page 2 KPIs)
- **Positive:** Parts where actual margin exceeds desired margin
- **Negative:** Parts where actual margin falls short of desired margin
- **Net:** Sum of positive and negative

## 5. Common Questions

### Why are the KPI cards different from the old report?

The old report had a DAX calculation bug that inflated the values. The new report is correct. See [Old Report Bug](../04-discoveries/Old-Report-Bug-Found.md) for details.

### Why doesn't Page 2 have relationships to other tables?

Page 2 uses `dim_Parts_LowMargin` as a standalone table for current inventory snapshot. It doesn't need transaction data. This is by design.

### Why do some transactions show blank for LowMarginFlag?

If a part was sold historically but is no longer in current inventory, the lookup to `dim_Parts_LowMargin` returns blank. This is expected.

### How often does the data refresh?

Depends on your Fabric workspace refresh schedule. Check the "Data last refreshed" timestamp in the report footer.

## 6. Exporting Data

**To export a visual:**
1. Click the three dots (...) on any visual
2. Select "Export data"
3. Choose format (Excel or CSV)

**To export the entire table:**
1. Go to Data view in Power BI Desktop
2. Right-click on the table name
3. Select "Copy table"
4. Paste into Excel

## 7. Next Steps

- **Learn more about the project:** [Project Summary](PROJECT-SUMMARY.md)
- **Set up from scratch:** [Setup Guide](../02-implementation/SETUP-GUIDE.md)
- **Understand the measures:** [Measure Reference](../02-implementation/MEASURE-REFERENCE.md)
- **Troubleshoot issues:** [Fixes Applied](../03-fixes-applied/)

## 8. Important Notes

⚠️ **The new report is MORE ACCURATE than the old report**
- Old report KPI cards showed inflated values due to a bug
- New report calculates correctly with direct column references
- Table data always matched - only KPI cards were wrong

✅ **All data has been validated**
- Compared row-by-row to old report
- All measures tested and verified
- Ready for production use

---

**Need help?** Check the [main README](../../README.md) for more resources.
