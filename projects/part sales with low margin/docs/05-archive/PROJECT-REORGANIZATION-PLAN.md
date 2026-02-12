# Project Reorganization Plan

## Current State
- **31+ documentation files** in the root directory
- Mix of analysis, fixes, guides, and historical documents
- Difficult to find current vs. superseded information
- No clear entry point for understanding the project

## Proposed New Structure

```
part sales with low margin/
├── README.md                           ← Main entry point
├── docs/
│   ├── 01-getting-started/
│   │   ├── QUICK-START.md             ← How to use this report
│   │   └── PROJECT-SUMMARY.md         ← What this project does
│   ├── 02-implementation/
│   │   ├── SETUP-GUIDE.md             ← How to set up from scratch
│   │   ├── DIMENSION-SETUP.md         ← Setting up dimensions
│   │   └── MEASURE-REFERENCE.md       ← All DAX measures documented
│   ├── 03-fixes-applied/
│   │   ├── KPI-Measures-Fix.md        ← Row context issue fix
│   │   ├── Calculated-Columns-Fix.md  ← Fact_InTrans fixes
│   │   ├── Page-2-Dimension-Fix.md    ← dim_Parts_LowMargin fixes
│   │   └── Customer-Dimension-Fix.md  ← dim_CustomerList deduplication
│   ├── 04-discoveries/
│   │   ├── Row-Count-Inflation.md     ← Why row counts were different
│   │   ├── Old-Report-Bug-Found.md    ← KPI cards were wrong in old report
│   │   └── Cost-vs-StockOrderPrice.md ← Field mapping discoveries
│   └── 05-archive/
│       └── [All superseded documents]
├── queries/
│   ├── dimensions/
│   │   ├── dim_Parts_LowMargin.pq     ← Current version
│   │   ├── dim_CustomerList.pq
│   │   └── archive/                   ← Old versions
│   └── diagnostics/
│       └── [Diagnostic queries]
└── reports/
    ├── current/                        ← Active report
    └── archive/                        ← Old report for reference
```

## File Categorization

### Keep as-is (Active Reference)
- queries/dimensions/*.pq (current dimension queries)
- reports/current/* (active Power BI files)

### Consolidate into Guides
**Getting Started:**
- README-IMPLEMENTATION.md → docs/01-getting-started/QUICK-START.md
- QUICK-START-CHECKLIST.md → docs/01-getting-started/QUICK-START.md (merge)

**Implementation:**
- POWER-BI-SETUP-GUIDE.md → docs/02-implementation/SETUP-GUIDE.md
- IMPLEMENTATION-GUIDE-FINAL.md → docs/02-implementation/SETUP-GUIDE.md (merge)
- IMPLEMENTATION-CHECKLIST.md → docs/02-implementation/SETUP-GUIDE.md (merge)
- DAX-MIGRATION-GUIDE.md → docs/02-implementation/MEASURE-REFERENCE.md
- HOW-TO-ADD-TMDL-MEASURES.md → docs/02-implementation/MEASURE-REFERENCE.md (merge)

**Fixes Applied:**
- FIX-KPI-Measures-Row-Context.md → docs/03-fixes-applied/KPI-Measures-Fix.md
- FIX-Fact_InTrans-Calculated-Columns.md → docs/03-fixes-applied/Calculated-Columns-Fix.md
- FIX-Page2-Use-Correct-Dimension.md + FIXES-Page2-Measure-Corrections.md → docs/03-fixes-applied/Page-2-Dimension-Fix.md
- FIX-dim_CustomerList-ManyToMany.md + SOLUTION-*.md → docs/03-fixes-applied/Customer-Dimension-Fix.md
- IMPLEMENTATION-GUIDE-Cost-Field-Fix.md → docs/03-fixes-applied/Page-2-Dimension-Fix.md (merge)
- MEASURES-WITH-COST-FIELD.md → docs/03-fixes-applied/Page-2-Dimension-Fix.md (merge)

**Discoveries:**
- DISCOVERY-Row-Count-Inflation-Issue.md → docs/04-discoveries/Row-Count-Inflation.md
- Create: Old-Report-Bug-Found.md (document that old KPIs were wrong)
- COLUMN-SOURCE-DECISION.md → docs/04-discoveries/Cost-vs-StockOrderPrice.md

**Archive (Historical/Superseded):**
- ANALYSIS-CustomerNo-Mapping.md
- CALCULATED-COLUMNS-ADDED.md
- CORRECTED-COLUMN-MAPPING.md
- ERROR-FIX-BULKBINQTY.md
- FIXED-Margin-Discrepancy-Measures.md
- InMaster-Impact-Analysis-FINAL.md
- InMaster-Load-Validation-Results.md
- MIGRATION-ANALYSIS.md
- PAGE-2-Inventory-Cost-Discrepancy-Mapping.md
- TMDL-*.md (multiple TMDL formatting fixes - historical)
- DAX-MEASURES-TMDL.txt (historical measure dump)

## Master README.md Content

```markdown
# Part Sales with Low Margin - Power BI Report

## Quick Links

- **[Quick Start Guide](docs/01-getting-started/QUICK-START.md)** - Get up and running
- **[Implementation Guide](docs/02-implementation/SETUP-GUIDE.md)** - Set up from scratch
- **[Measure Reference](docs/02-implementation/MEASURE-REFERENCE.md)** - All DAX measures
- **[Fixes Applied](docs/03-fixes-applied/)** - Key issues resolved during migration

## What This Report Does

Analyzes part sales with low margins across branches and franchises. Identifies:
- Parts with low margin flags
- Inventory cost discrepancies
- Margin analysis by part, branch, and franchise

## Key Pages

1. **Parts Sales with Low Margins** - Transaction-level margin analysis
2. **Inventory Cost Discrepancy** - Current inventory margin gaps
3. **Low Action Items** - Parts requiring pricing action

## Important Discoveries

During migration from the old report, we discovered and fixed:
- **Old report KPI cards were WRONG** - Had a DAX measure evaluation bug showing inflated values
- **Row count inflation** - Dimension had 7x more rows due to missing filtering
- **Cost vs StockOrderPrice** - Old report used different field for calculations

See [Discoveries](docs/04-discoveries/) for details.

## Current Status

✅ Report migrated and validated
✅ All major bugs fixed
✅ New report MORE ACCURATE than old report
✅ Ready for production use

## Project Structure

- `/docs/` - All documentation organized by topic
- `/queries/` - Power Query (M) dimension queries
- `/reports/` - Power BI project files
```

## Benefits of This Structure

1. **Clear navigation** - Numbered folders guide you through the journey
2. **Consolidated information** - Related docs merged, reducing duplication
3. **Historical preservation** - Archive folder keeps old docs without cluttering
4. **Easy onboarding** - README → Quick Start → Implementation Guide path
5. **Discoverable fixes** - All fixes in one place with clear names
6. **Reference material** - Measures and setup guides easily found

## Next Steps

Would you like me to:
1. Create the new folder structure
2. Consolidate the documents (merge related files)
3. Create the master README.md
4. Move files to archive

I can do this step-by-step or all at once. What's your preference?
