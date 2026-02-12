# Project Summary

## Overview

The **Part Sales with Low Margin** report is a Power BI analytics tool that helps identify and analyze parts with low profit margins across all branches and franchises. It provides both historical transaction analysis and current inventory snapshots to support pricing decisions.

## Business Purpose

### Primary Objectives

1. **Identify Low Margin Parts** - Flag parts that are not meeting target profit margins
2. **Quantify Margin Gaps** - Measure the financial impact of margin discrepancies
3. **Guide Pricing Actions** - Provide recommended sell prices to achieve targets
4. **Monitor Margin Trends** - Track margin performance over time by part, branch, and franchise

### Key Users

- **Pricing Managers** - Set and adjust part pricing
- **Branch Managers** - Monitor branch-specific margin performance
- **Finance Team** - Analyze profitability and margin trends
- **Operations** - Identify parts requiring pricing action

## Report Structure

### Page 1: Parts Sales with Low Margins
**Transaction-Level Analysis**

Shows every sales transaction with margin calculations, allowing users to:
- See which parts are being sold below target margins
- Identify patterns by customer, salesman, branch, or time period
- Compare actual margins to original expected margins
- Filter to specific parts or date ranges

**Data Source:** Fact_InTrans (transaction data)

### Page 2: Inventory Cost Discrepancy
**Current Inventory Snapshot**

Analyzes parts currently in stock with margin discrepancies:
- KPI cards showing total positive, negative, and net discrepancies
- Detailed table of parts with margin gaps
- Recommended new sell prices to close margin gaps
- Focus on actionable current inventory (not historical sales)

**Data Source:** dim_Parts_LowMargin (current inventory snapshot)

### Page 3: Low Action Items
**Prioritized Action List**

Filtered view highlighting parts needing immediate attention based on margin impact.

## Key Metrics

### Transaction Metrics (Page 1)

| Metric | Description | Formula |
|--------|-------------|---------|
| **Actual Margin $** | Profit from the actual sale | Sale Value - Cost Value |
| **Actual Margin %** | Profit percentage | Actual Margin $ / Sale Value |
| **Original Margin $** | Expected profit at stock order price | (Sale Value / Qty - Stock Order Price) * Qty |
| **Original Margin %** | Expected profit percentage | Original Margin $ / Sale Value |
| **Margin Discrepancy $** | Gap between actual and expected | Actual Margin $ - Original Margin $ |

### Inventory Metrics (Page 2)

| Metric | Description | Formula |
|--------|-------------|---------|
| **Desired Margin $** | Target profit based on Cost | Sell Value - Cost Value |
| **Desired Margin %** | Target profit percentage | Desired Margin $ / Sell Value |
| **Actual Margin $ (INV)** | Current profit potential | Sell Value - Inventory Cost |
| **Actual Margin % (INV)** | Current profit percentage | Actual Margin $ (INV) / Sell Value |
| **Margin $ Discrepancy** | Gap to close | Actual Margin $ (INV) - Desired Margin $ |

### KPI Cards (Page 2)

| KPI | Meaning |
|-----|---------|
| **Positive Margin $ Discrepancy** | Total value of parts exceeding target margins |
| **Negative Margin $ Discrepancy** | Total value of parts below target margins |
| **Net Margin $ Discrepancy** | Overall margin gap (positive + negative) |

## Migration from Old Report

This report is a **complete rewrite** of the legacy "Parts Sales with Low Margins" report, with significant improvements:

### What Changed

✅ **Data Model** - Rebuilt with proper star schema and optimized dimensions
✅ **DAX Measures** - Fixed calculation bugs, especially in KPI cards
✅ **Dimensions** - Created specialized dim_Parts_LowMargin for Page 2
✅ **Performance** - Eliminated 7x row inflation through proper filtering
✅ **Accuracy** - Validated row-by-row against old report

### What Stayed the Same

- Report pages and layout
- Business logic and filtering rules
- Field names and measure names (where possible)
- Visual formatting and colors

### Critical Discovery

**The old report's KPI cards were wrong!**
- Showed $5.31M when actual data was $2.20M
- Caused by DAX measure evaluation bug in row context
- New report fixes this with direct column calculations
- Table data was always correct - only KPI cards were wrong

See [Old Report Bug Found](../04-discoveries/Old-Report-Bug-Found.md) for technical details.

## Data Sources

### Primary Sources

1. **Fact_InTrans** - Sales transaction fact table from InTrans
2. **dim_Parts** - Part master dimension from Lakehouse
3. **dim_Parts_LowMargin** - Specialized dimension for inventory analysis
4. **dim_CustomerList** - Customer master from Lakehouse
5. **dim_BranchLocation** - Branch master from Lakehouse
6. **dim_Date** - Standard date dimension

### Source Systems

- **ERP System** - Transaction data via InTrans table
- **jdis_Part_Information** - Part pricing and inventory data
- **InMaster** - Part metadata including low margin flags
- **ArMaster** - Customer master data

## Technical Architecture

### Data Flow

```
ERP System (InTrans, jdis, InMaster, ArMaster)
    ↓
Fabric Lakehouse (Dimensions built via Power Query)
    ↓
Power BI Report (DAX measures and visualizations)
```

### Key Technical Decisions

1. **dim_Parts_LowMargin is standalone** - No relationships to Fact_InTrans
   - Page 2 shows current inventory snapshot
   - Uses LOOKUPVALUE in calculated columns instead of relationships

2. **Direct column calculations in KPI measures**
   - Avoids DAX row context evaluation bugs
   - Ensures accurate aggregation

3. **Branch + Franchise granularity**
   - Dimensions track branch-specific pricing
   - Supports multi-branch, multi-franchise analysis

See [Setup Guide](../02-implementation/SETUP-GUIDE.md) for implementation details.

## Success Criteria

This project is considered successful if:

✅ **Accuracy** - All measures match or improve upon old report
✅ **Performance** - Report loads in acceptable time (<10 seconds)
✅ **Usability** - Users can find and interpret data easily
✅ **Maintainability** - Documentation allows future updates
✅ **Trust** - Stakeholders confidence in the numbers

**Current Status:** All criteria met ✅

## Next Steps

- Review the [Quick Start Guide](QUICK-START.md) to use the report
- Check [Setup Guide](../02-implementation/SETUP-GUIDE.md) to replicate
- Explore [Fixes Applied](../03-fixes-applied/) to understand changes
- Read [Discoveries](../04-discoveries/) to learn what we found

---

**Project Type:** Power BI Report Migration
**Status:** Complete and Validated
**Accuracy Level:** Higher than original report
**Last Updated:** January 2026
