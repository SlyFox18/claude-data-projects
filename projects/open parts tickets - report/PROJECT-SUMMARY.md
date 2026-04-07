# Open Parts Tickets - Project Summary

**Project Status**: ✅ Production — Active development (March 2026)
**Last Updated**: March 5, 2026
**Original Migration**: January 2026 (v2.0)

---

## CURRENT STATUS (March 2026)

The report is fully built, in production, and receiving new feature additions. The original January 2026 modernization (flat Lakehouse → star schema) is 100% complete. Two new stakeholder-requested features were added in March 2026.

### Active Infrastructure (March 2026)

✅ **Monthly Snapshot** (March 2026)
- Notebook: `nb_Snapshot_Parts_Open_Orders` in LH_Master_Data
- Target table: `fact_parts_open_orders_snapshot` (Delta, append mode)
- Pipeline: `Pipeline_Monthly_Open_Orders_Snapshot` — 5:30 AM on the 1st of each month
- First snapshot: March 1, 2026. History builds from here — no backfill possible.
- Semantic model table wired to `dim_DateTable` (via `SnapshotDate`) and `dim_BranchLocation`

✅ **Open Invoice Ratio** (March 2026)
- New semantic model table: `Fact_PartsInvoiced_ByBranch` — SQL endpoint native query, aggregates Invoice table by Branch + Month
- Excludes Internal customers (71-87, 9001-9007) and Warranty customers (41-57, 9051-9057)
- New slicer table: `Trailing_Months_Selector` (3 / 6 / 12 / 24 months)
- New measures (display folder: "Open Order Ratio"):
  - `Selected Trailing Months` — reads slicer, defaults to 12
  - `Invoiced Parts (Trailing)` — SUM of PartsSaleValue for the selected trailing window
  - `Open Order Ratio` — DIVIDE([Order Total], [Invoiced Parts (Trailing)])
- Visual: Ratio tab on Comparison page — bar chart sorted by ratio descending

### What's Pending (Future Work)

⏳ **Snapshot trend page** — needs a few months of data before building. Come back May/June 2026.

⏳ **Ratio validation** — ratios are live and calculating (0.4%–8.5% range as of March 2026). Monitor for a few months to confirm stability.

---

## ORIGINAL EXECUTIVE SUMMARY (January 2026)

This project modernized the "Open Parts Tickets" report from an outdated Lakehouse structure to a new star schema architecture optimized for F4 capacity performance.

---

## DOCUMENTATION FILES CREATED

### 1. [MIGRATION-STATUS.md](./MIGRATION-STATUS.md)
**Purpose**: Complete project status and implementation roadmap

**Key Sections**:
- ✅ Completed Work (semantic model, measures, relationships)
- 🔧 Remaining Work (20 measures, report pages)
- 📋 How to Complete Migration (3 options)
- 🎨 Report Rebuild Guide (page layouts)
- 📊 Data Refresh Strategy (F4 optimization)
- 🐛 Known Issues & Fixes
- ✅ Next Steps (prioritized)

**Use this for**: Project tracking, understanding what's done vs. what's left

### 2. [DAX-MEASURES-REFERENCE.md](./DAX-MEASURES-REFERENCE.md)
**Purpose**: Complete library of all 39 DAX measures with updated table names

**Key Sections**:
- Table Name Mapping (old → new)
- Core Business Metrics (14 measures)
- Percentage Calculations (3 measures)
- Branch Comparison Measures (7 measures)
- Customer Analysis Measures (9 measures)
- Salesman Analysis Measures (6 measures)
- Time Intelligence (1 measure)
- SVG Measures (8 complex visual measures)

**Use this for**: Copy-paste measure definitions, understanding measure logic

### 3. [REPORT-PAGES-GUIDE.md](./REPORT-PAGES-GUIDE.md)
**Purpose**: Detailed specifications for building all 4 report pages

**Key Sections**:
- Page 1: Overview (aging matrix + KPI cards)
- Page 2: On Order Details (detailed table)
- Page 3: Comparison (branch/customer/salesman rankings)
- Page 4: Charts (trends and distributions)
- Global Settings (page size, fonts, filters)
- Color Palette (consistent branding)
- Best Practices (performance, UX, maintenance)
- Implementation Checklist (step-by-step)

**Use this for**: Building report pages in Power BI Desktop, visual specifications

---

## QUICK START GUIDE

### Option A: Complete Measures in Power BI Desktop (Recommended)

**Why**: Best for learning, easier troubleshooting, immediate visual feedback

**Steps**:
1. Open Power BI Desktop
2. Open: `reports/current/Open Parts Tickets.SemanticModel`
3. Go to **Model view**
4. For each measure in [DAX-MEASURES-REFERENCE.md](./DAX-MEASURES-REFERENCE.md):
   - Click **New Measure**
   - Copy DAX code (table names already updated)
   - Set format string and display folder
5. Save and publish

**Time estimate**: 2-3 hours for all 20 remaining measures

### Option B: Fix TMDL File Directly

**Why**: Version control, can be automated, works with Git

**Steps**:
1. Open: `reports/current/Open Parts Tickets.SemanticModel/definition/tables/_Measures.tmdl`
2. Add remaining measures from [DAX-MEASURES-REFERENCE.md](./DAX-MEASURES-REFERENCE.md)
3. Follow TMDL syntax rules:
   - No empty lines between measures
   - Proper indentation (tabs)
   - Escape special characters in format strings
4. Test by opening in Power BI Desktop

**Time estimate**: 1-2 hours (if familiar with TMDL syntax)

### Option C: Hybrid Approach

**Why**: Get complex measures working first, add simple ones via TMDL later

**Steps**:
1. Add 8 SVG measures in Power BI Desktop (most complex)
2. Add customer/salesman ranking measures in Power BI Desktop
3. Export to TMDL
4. Use TMDL for future maintenance

**Time estimate**: 2 hours

---

## IMPLEMENTATION ROADMAP

### Phase 1: Complete DAX Measures (2-3 hours)

**Priority 1 - KPI Visual Measures** (Required for Overview page):
- `KPI SVG - Not Backordered vs Backordered (Conditional Color)`
- `KPI SVG - Parts On Order vs Back Order (Conditional Color)`
- `KPI SVG - Line Count vs Backordered Line (Conditional Color)`
- `KPI SVG - Orders vs Orders with BO Parts (Conditional Color)`

**Priority 2 - Customer/Salesman Analysis** (Required for Comparison page):
- `Selected Top N`
- `Customer Rank - Order Count`
- `Customer Rank - Order Total`
- `Filtered Order Count`
- `Filtered Order Total`
- `Salesman Rank - Order Count`
- `Salesman Rank - Order Total`
- `Filtered Order Count - Salesman`
- `Filtered Order Total - Salesman`

**Priority 3 - Branch Comparison** (Nice to have):
- `HighestValueCount`
- `LowestValueCount`
- `Bar Color Order Count`
- `Bar Color Hex Order Total`
- `Bar Color Hex Back Order`
- `Bar Color Hex $$ not BO`
- `Back Order Label`

**Priority 4 - Additional Visual Measures** (Optional):
- 4 "compact" versions of SVG measures
- `Bar Color Hex - Customer Count`
- `Bar Color Hex - Customer Total`
- `Bar Color Hex - Salesman Count`
- `Bar Color Hex - Salesman Total`

### Phase 2: Build Overview Page (2 hours)

Use [REPORT-PAGES-GUIDE.md](./REPORT-PAGES-GUIDE.md) - Page 1 section

**Visuals to create**:
1. Header (HTML/text box with `[Home - Header]` measure)
2. Filter display card (`[Show Filter 1]`)
3. Slicers (Aging, Branch, Invoice Type, Order Date)
4. Aging matrix with conditional formatting
5. 4 KPI cards using SVG measures

**Success criteria**:
- Aging sorts correctly (0-7, 8-14, 15-30, 31-60, 61-90, 90+)
- KPI cards display with visual bars
- Filters sync and display correctly

### Phase 3: Build Details Page (1 hour)

Use [REPORT-PAGES-GUIDE.md](./REPORT-PAGES-GUIDE.md) - Page 2 section

**Visuals to create**:
1. Page title
2. Detail table with all 16 columns
3. Conditional formatting (backorders, aging colors)
4. Drill-through from Overview page

**Success criteria**:
- All columns display correctly
- Backordered rows highlighted in red
- Aging color gradient applied

### Phase 4: Build Comparison Page (1.5 hours)

Use [REPORT-PAGES-GUIDE.md](./REPORT-PAGES-GUIDE.md) - Page 3 section

**Visuals to create**:
1. Branch performance matrix
2. TopN Selector table (disconnected)
3. Customer rankings table
4. Salesman rankings table

**Success criteria**:
- Branch highlighting shows max/min correctly
- TopN selector filters customer/salesman tables
- Rankings sort correctly

### Phase 5: Build Charts Page (1 hour)

Use [REPORT-PAGES-GUIDE.md](./REPORT-PAGES-GUIDE.md) - Page 4 section

**Visuals to create**:
1. Aging distribution donut chart
2. Orders over time line chart
3. Top customers bar chart
4. Branch comparison column chart

**Success criteria**:
- Color scheme consistent with aging gradient
- Charts interactive with slicers
- Trends display correctly

### Phase 6: Testing & Deployment (1 hour)

**Validation**:
- [ ] Compare totals with old report (should match exactly)
- [ ] Test all slicers and filters
- [ ] Verify drill-through works
- [ ] Check mobile layout
- [ ] Test export to Excel/PDF

**Deployment**:
- [ ] Publish to Fabric workspace
- [ ] Configure scheduled refresh (6 AM and 1 PM)
- [ ] Set up alerts for refresh failures
- [ ] Share with stakeholders
- [ ] Archive old report

**Total estimated time**: 8-10 hours spread across 2-3 days

---

## DATA ARCHITECTURE

### Source Tables (Fabric Warehouse: LH_Master_Data)

**Fact Tables**:
- `Fact_Parts_Open_Tickets` - Order summary level (1 row per order)
- `Fact_Parts_Open_Tickets_Details` - Line item detail (1 row per part)

**Dimension Tables**:
- `dim_BranchLocation` - Branch master data
- `dim_DateTable` - Complete date dimension

### Relationships (3 total)

```
Fact_Parts_Open_Tickets_Details[Order_No] → Fact_Parts_Open_Tickets[Order_No]
Fact_Parts_Open_Tickets_Details[Location] → dim_BranchLocation[BranchID]
Fact_Parts_Open_Tickets_Details[Order_Date] → dim_DateTable[Date]
```

### Key Columns

**Aging Calculation**:
- `Days_Open` = DATEDIFF between order date and today
- `Aging` = Text bucket (0-7, 8-14, 15-30, 31-60, 61-90, 90+ days)
- `Aging_Sort_Order` = Numeric sort (1-6)
- **Important**: `Aging` column must be set to `sortByColumn: Aging_Sort_Order`

**Currency Columns** (format: `\$#,0.00;(\$#,0.00);\$#,0.00`):
- `Order_Total_$$`
- `$$_Available`
- `$$_BackOrdered`
- `Deposit`

**Quantity Columns** (format: `#,0`):
- `#_Parts_On_Order`
- `#_On_Back_Order`

---

## F4 CAPACITY OPTIMIZATION STRATEGIES

### Current Setup
- **Capacity**: F4 (small tier)
- **CU Limit**: Limited capacity units
- **Concern**: Refresh costs and report performance

### Optimization Techniques Applied

**1. Star Schema Architecture**
- ✅ Fact tables separated from dimensions
- ✅ Relationships configured for optimal joins
- ✅ Aggregations pre-calculated in fact tables

**2. Incremental Refresh Strategy**
- Partition by `Order_Date`
- Refresh last 30 days incrementally
- Full refresh quarterly only
- Saves ~70% refresh time

**3. Measure Optimization**
- ✅ Use measures instead of calculated columns
- ✅ Avoid row context where possible
- ✅ Use COUNTROWS instead of SUM on calculated columns

**4. Visual-Level Filters**
- Prefer visual-level filters over page-level
- Reduces query load
- Improves responsiveness

**5. Limited Row Display**
- Detail table limited to 1000 rows with "See more"
- TopN filters on customer/salesman tables
- Reduces memory usage

**6. Scheduled Refresh Timing**
- Morning: 6:00 AM (before business hours)
- Afternoon: 1:00 PM (mid-day update)
- Avoids peak usage times

### Performance Targets

**Refresh Time**: < 5 minutes (currently unknown)
**Report Load**: < 3 seconds (target)
**Visual Render**: < 1 second (target)

**Next steps**: Monitor actual performance after deployment, adjust as needed

---

## TABLE NAME MAPPING (Old → New)

Critical for migrating any remaining code or documentation:

| Old Name | New Name |
|----------|----------|
| `Parts_Open_Tickets` | `Fact_Parts_Open_Tickets` |
| `Parts_Open_Tickets_Details` | `Fact_Parts_Open_Tickets_Details` |
| `Dim_Branch` | `dim_BranchLocation` |
| `dimDate` | `dim_DateTable` |

**Find/Replace Strategy**:
If copying from old report exports, use these exact replacements in order:
1. `Parts_Open_Tickets_Details` → `Fact_Parts_Open_Tickets_Details` (do this first!)
2. `Parts_Open_Tickets` → `Fact_Parts_Open_Tickets` (then this)
3. `Dim_Branch` → `dim_BranchLocation`
4. `dimDate` → `dim_DateTable`

**Why order matters**: "Parts_Open_Tickets" is a substring of "Parts_Open_Tickets_Details", so if you replace the shorter one first, you'll get incorrect results.

---

## KNOWN ISSUES & SOLUTIONS

### Issue 1: TMDL Syntax Complexity
**Status**: Worked around with documentation approach
**Impact**: 20 measures need to be added manually
**Solution**: Use Power BI Desktop (Option A) or fix TMDL carefully (Option B)

### Issue 2: Backordered Line Count Calculation
**Old approach**: Used calculated column `BackOrdered Flag`
**New approach**: Direct measure `SUM(Fact_Parts_Open_Tickets_Details[BackOrdered_QTY])`
**Why changed**: Avoid calculated columns for F4 optimization

### Issue 3: SVG Measures May Not Display
**Cause**: Power BI sometimes restricts HTML content
**Solution**:
- Use Card visual (not HTML content visual)
- Ensure measure returns string value
- If still blocked, use compact versions without conditional colors

### Issue 4: Aging Not Sorting Correctly
**Cause**: `Aging` column missing `sortByColumn` property
**Solution**: ✅ Already fixed in `Fact_Parts_Open_Tickets.tmdl`
**Verify**: `column Aging` has `sortByColumn: Aging_Sort_Order`

---

## SUCCESS METRICS

### Data Accuracy
- [ ] Total Order Count matches old report exactly
- [ ] Order Total $ matches old report exactly
- [ ] Backordered $ matches old report exactly
- [ ] Aging buckets match old report counts

### Performance
- [ ] Refresh completes in < 5 minutes
- [ ] Report loads in < 3 seconds
- [ ] All visuals render in < 1 second
- [ ] No timeout errors on F4 capacity

### Functionality
- [ ] All 4 pages built and working
- [ ] All 39 measures calculated correctly
- [ ] Slicers sync across pages
- [ ] Drill-through works from Overview to Details
- [ ] TopN selector filters customer/salesman rankings
- [ ] Mobile layout tested and working

### User Acceptance
- [ ] Stakeholders approve visual design
- [ ] Report provides same insights as old version
- [ ] New features enhance analysis capability
- [ ] Documentation enables self-service

---

## FILE STRUCTURE REFERENCE

```
projects/parts on open orders/
├── PROJECT-SUMMARY.md                    ← You are here
├── MIGRATION-STATUS.md                   ← Project status tracking
├── DAX-MEASURES-REFERENCE.md            ← Complete measure library
├── REPORT-PAGES-GUIDE.md                ← Page specifications
│
├── queries/
│   ├── fact-tables/
│   │   ├── Fact_Parts_Open_Tickets.sql          ✅ Used to create fact table
│   │   └── Fact_Parts_Open_Tickets_Details.sql  ✅ Used to create fact table
│   └── old report queries/
│       ├── Parts_Open_Tickets.pq                📚 Reference only
│       └── RepairOrderDetail.pq                 📚 Reference only
│
├── info-exports/
│   ├── old report/
│   │   ├── Model Measures.csv                   📚 Source of measure definitions
│   │   ├── Model Columns.csv                    📚 Column mappings
│   │   ├── Model Tables.csv                     📚 Table structure
│   │   └── Model Relationship.csv               📚 Old relationships
│   └── new report/                              ⏳ TODO: Export after completion
│
├── screenshots/
│   ├── old report/
│   │   ├── Page 1.jpg                           📚 Overview page reference
│   │   └── Page 2.jpg                           📚 Details page reference
│   └── new report/                              ⏳ TODO: Document new pages
│
└── reports/
    ├── archive/
    │   └── Open Parts Tickets - Old.pbix      📚 Archived old report
    └── current/
        ├── Open Parts Tickets.SemanticModel/  ✅ 75% Complete
        │   ├── definition/
        │   │   ├── tables/
        │   │   │   ├── _Measures.tmdl           ✅ 19 measures done, 20 to add
        │   │   │   ├── Fact_Parts_Open_Tickets.tmdl  ✅ Complete
        │   │   │   ├── Fact_Parts_Open_Tickets_Details.tmdl
        │   │   │   ├── dim_BranchLocation.tmdl
        │   │   │   └── dim_DateTable.tmdl
        │   │   ├── relationships.tmdl           ✅ 3 relationships configured
        │   │   └── model.tmdl
        │   └── definition.pbism
        └── Open Parts Tickets.Report/         ⏳ Not started - build here!
```

---

## NEXT ACTIONS FOR YOU

### Immediate (Today - 2-3 hours)

**Option A: Power BI Desktop (Recommended)**
1. Open Power BI Desktop
2. Open semantic model: `reports/current/Open Parts Tickets.SemanticModel`
3. Go to Model view → New Measure
4. Add Priority 1 measures (4 KPI SVG measures) from [DAX-MEASURES-REFERENCE.md](./DAX-MEASURES-REFERENCE.md)
5. Add Priority 2 measures (customer/salesman rankings)
6. Test measures return correct values
7. Save and continue to report building

**Option B: TMDL File (Advanced)**
1. Open VS Code
2. Open `_Measures.tmdl`
3. Add remaining measures following TMDL syntax
4. Remove any empty lines between measures
5. Test by opening in Power BI Desktop

### This Week (6-8 hours)

1. **Build Overview Page** (2 hours)
   - Follow [REPORT-PAGES-GUIDE.md](./REPORT-PAGES-GUIDE.md) - Page 1
   - Test aging matrix sorts correctly
   - Verify KPI cards display

2. **Build Details Page** (1 hour)
   - Follow [REPORT-PAGES-GUIDE.md](./REPORT-PAGES-GUIDE.md) - Page 2
   - Apply conditional formatting
   - Test drill-through

3. **Build Comparison & Charts Pages** (2.5 hours)
   - Follow [REPORT-PAGES-GUIDE.md](./REPORT-PAGES-GUIDE.md) - Pages 3-4
   - Create TopN Selector table
   - Apply color scheme

4. **Validate & Deploy** (1 hour)
   - Compare totals with old report
   - Publish to Fabric workspace
   - Configure scheduled refresh

### Next Week

1. Monitor first few refreshes for performance
2. Gather user feedback
3. Create final documentation exports
4. Archive old report
5. Update [MIGRATION-STATUS.md](./MIGRATION-STATUS.md) to 100% complete

---

## SUPPORT & TROUBLESHOOTING

### If You Get Stuck

**Measure not calculating correctly?**
→ Check [DAX-MEASURES-REFERENCE.md](./DAX-MEASURES-REFERENCE.md) for exact DAX
→ Verify table names match (Fact_Parts_Open_Tickets, not Parts_Open_Tickets)
→ Check column names are exact (case-sensitive)

**Visual not displaying?**
→ Check [REPORT-PAGES-GUIDE.md](./REPORT-PAGES-GUIDE.md) for visual type
→ Verify fields are in correct wells (Rows vs. Values)
→ Check conditional formatting measure returns 0/1 not TRUE/FALSE

**Aging not sorting?**
→ Verify in Model view: `Aging` column → Properties → Sort by column = `Aging_Sort_Order`

**Slow refresh?**
→ Check [MIGRATION-STATUS.md](./MIGRATION-STATUS.md) - F4 Optimization Tips section
→ Enable incremental refresh
→ Limit detail table to 1000 rows initially

**TMDL syntax error?**
→ Remove empty lines between measures
→ Ensure proper indentation (tabs, not spaces)
→ Escape special characters in strings (`\$` for dollar signs)

### Reference Projects

**Similar completed project**: `projects/inspections-report/`
- Look at this project's documentation structure
- See how measures are organized
- Reference page layouts and color schemes

### External Resources

- **Power BI Community**: https://community.powerbi.com/
- **DAX Guide**: https://dax.guide/
- **SQLBI**: https://www.sqlbi.com/ (best practices)
- **Microsoft Docs**: https://docs.microsoft.com/en-us/power-bi/

---

## PROJECT TIMELINE

| Phase | Status | Time Spent | Time Remaining | Total |
|-------|--------|------------|----------------|-------|
| Data Architecture | ✅ Complete | 4 hours | 0 | 4 hours |
| Semantic Model Setup | ✅ 75% | 2 hours | 1 hour | 3 hours |
| DAX Measures Migration | ✅ 50% | 2 hours | 2 hours | 4 hours |
| Documentation | ✅ Complete | 3 hours | 0 | 3 hours |
| Report Pages | ⏳ Not started | 0 | 6 hours | 6 hours |
| Testing & Deployment | ⏳ Not started | 0 | 1 hour | 1 hour |
| **TOTAL** | **75%** | **11 hours** | **10 hours** | **21 hours** |

**Estimated completion**: 2-3 business days (if working full-time)

---

## CONCLUSION

You're 75% complete with the modernization! The data foundation is solid, measures are well-documented, and detailed specifications exist for every report page.

**The path forward is clear**:
1. Add remaining 20 measures (use [DAX-MEASURES-REFERENCE.md](./DAX-MEASURES-REFERENCE.md))
2. Build 4 report pages (use [REPORT-PAGES-GUIDE.md](./REPORT-PAGES-GUIDE.md))
3. Test, validate, and deploy

**Estimated time to finish**: 8-10 hours

All the hard research, planning, and documentation work is done. Now it's just methodical execution following the guides.

**You've got this!** 🚀

---

**Questions or need help?**
- Review the documentation files first
- Check the troubleshooting sections
- Reference the inspections-report project for examples
- All measure definitions are ready to copy-paste

**Good luck with the final implementation!**

---

**Document Version**: 1.0
**Last Updated**: January 6, 2026
**Created By**: Claude Code - Power BI Modernization Assistant
