# Part Sales with Low Margin - Power BI Report

## 📋 Quick Links

- **[Quick Start Guide](docs/01-getting-started/QUICK-START.md)** - Get up and running in 5 minutes
- **[Project Summary](docs/01-getting-started/PROJECT-SUMMARY.md)** - What this report does
- **[Setup Guide](docs/02-implementation/SETUP-GUIDE.md)** - Complete implementation instructions
- **[DAX Measures Reference](docs/02-implementation/MEASURE-REFERENCE.md)** - All measures documented
- **[Fixes Applied](docs/03-fixes-applied/)** - Key issues resolved during migration
- **[Discoveries](docs/04-discoveries/)** - Important findings about the old report

## 🎯 What This Report Does

Analyzes part sales with low profit margins across all branches and franchises to identify:
- Parts flagged with low margins in the ERP system
- Inventory cost discrepancies between desired and actual margins
- Transaction-level margin analysis for pricing decisions
- Action items for parts requiring price adjustments

## 📊 Report Pages

### 1. Parts Sales with Low Margins
Transaction-level analysis showing:
- All sales transactions with margin calculations
- Filtering by low margin flag, branch, franchise
- Actual vs. original margin comparison
- Customer and salesman breakdowns

### 2. Inventory Cost Discrepancy
Current inventory snapshot showing:
- Parts with margin gaps between desired and actual
- Inventory value at risk from margin discrepancies
- KPI cards: Positive, Negative, and Net discrepancies
- Recommended new sell prices to achieve target margins

### 3. Low Action Items
Action-oriented view highlighting:
- Parts requiring immediate pricing attention
- Prioritized by margin impact

## ✅ Current Status

**Migration Complete and Validated**
- ✅ All data sources migrated from old report
- ✅ Dimensions built and optimized
- ✅ DAX measures implemented with direct column calculations
- ✅ Major bugs discovered and fixed
- ✅ **New report is MORE ACCURATE than the old report**

## 🔍 Key Discoveries During Migration

We found and fixed several critical issues:

1. **Old Report KPI Cards Were Wrong** ([Details](docs/04-discoveries/Old-Report-Bug-Found.md))
   - Had a DAX measure evaluation bug
   - Showed $5.31M when actual was $2.20M
   - New report calculates correctly

2. **Row Count Inflation** ([Details](docs/04-discoveries/Row-Count-Inflation.md))
   - Dimension had 7x more rows than needed
   - Fixed with proper filtering logic

3. **Column Source Clarification** ([Details](docs/04-discoveries/Cost-vs-StockOrderPrice.md))
   - Identified which cost field to use
   - Documented field mappings from old to new

## 🏗️ Project Structure

```
part sales with low margin/
├── README.md                    ← You are here
├── docs/
│   ├── 01-getting-started/     ← Start here if new to the project
│   ├── 02-implementation/      ← Setup guides and references
│   ├── 03-fixes-applied/       ← Solutions to issues encountered
│   ├── 04-discoveries/         ← Important findings
│   └── 05-archive/             ← Historical documents
├── queries/
│   ├── dimensions/             ← Power Query (M) files for dimensions
│   ├── diagnostics/            ← Diagnostic queries
│   └── archive/                ← Old query versions
└── reports/
    ├── current/                ← Active Power BI report
    └── archive/                ← Old report for reference
```

## 🚀 Getting Started

**New to this project?** Start here:

1. Read the [Project Summary](docs/01-getting-started/PROJECT-SUMMARY.md)
2. Follow the [Quick Start Guide](docs/01-getting-started/QUICK-START.md)
3. Review [Fixes Applied](docs/03-fixes-applied/) to understand what was changed

**Setting up from scratch?**

1. Follow the [Setup Guide](docs/02-implementation/SETUP-GUIDE.md)
2. Reference the [Measure Guide](docs/02-implementation/MEASURE-REFERENCE.md) for DAX formulas

**Troubleshooting?**

Check the [Fixes Applied](docs/03-fixes-applied/) folder for common issues and solutions.

## 📈 Data Sources

- **Fact_InTrans** - Sales transaction data from InTrans table
- **dim_Parts** - Part master dimension from Lakehouse
- **dim_Parts_LowMargin** - Specialized dimension for Page 2 analysis
- **dim_CustomerList** - Customer master dimension from Lakehouse
- **dim_BranchLocation** - Branch master dimension from Lakehouse
- **dim_Date** - Standard date dimension

## 🔑 Key Measures

**Margin Analysis:**
- Actual Margin $ / %
- Original Margin $ / %
- Margin Discrepancy $

**Inventory Analysis (Page 2):**
- Positive/Negative/Net Margin $ Discrepancy
- Desired Margin $ / %
- Cost Value
- Sell Value

See [Measure Reference](docs/02-implementation/MEASURE-REFERENCE.md) for complete DAX formulas.

## 🏆 Why This Report Is Better Than The Old Report

1. **Correct KPI Calculations** - Fixed DAX row context issue
2. **Proper Dimension Design** - Branch-specific lookups work correctly
3. **Optimized Performance** - Filtered out unnecessary rows
4. **Better Documentation** - Everything is documented and organized
5. **Validated Accuracy** - Compared row-by-row to old report

## 📞 Support

For questions or issues:
1. Check the [Fixes Applied](docs/03-fixes-applied/) documentation
2. Review the [Discoveries](docs/04-discoveries/) for known issues
3. Consult the [Measure Reference](docs/02-implementation/MEASURE-REFERENCE.md) for DAX questions

---

**Last Updated:** January 2026
**Status:** Production Ready
**Version:** 2.0 (Migrated from legacy report)
