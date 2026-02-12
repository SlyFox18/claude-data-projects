# Parts Promo Report - Migration Project Status

**Last Updated:** 2026-01-19
**Status:** In Progress - Data Layer Complete, Testing Phase

---

## Project Overview

**Objective:** Migrate Parts Promo report from old Lakehouse (direct ODBC) to new Lakehouse structure (InTrans_Incremental), while improving the data model design.

**Key Decision:** User opted for **redesign over replication** - wanting better insights, not just exact copy of old report.

---

## Current Status Summary

| Component | Status | Notes |
|-----------|--------|-------|
| Fact_PartsPromo_v2 | Working | 12K+ rows, in Fabric dataflow |
| Fact_InTrans_AllPromo | Working | Use directly in report (not dataflow) |
| dim_PromoType | Created | Needs testing in Fabric |
| dim_RepairOrder | Created | Needs testing in Fabric |
| Semantic Model | Not Started | Next phase |
| DAX Measures | Not Started | After semantic model |
| Report Visuals | Not Started | Final phase |

---

## Completed Work

### 1. Query Development

**New Queries Created:**

| Query | Purpose | Location |
|-------|---------|----------|
| Fact_PartsPromo_v2.pq | Promo transactions (simplified) | queries/new report/fact tables/ |
| Fact_InTrans_AllPromo_ForReport.pq | All transactions (for report) | queries/new report/fact tables/ |
| dim_PromoType.pq | Promo part categorization | queries/new report/dimensions/ |
| dim_RepairOrder.pq | Pre-aggregated order context | queries/new report/dimensions/ |

**Diagnostic Queries:**
- Test_PromoFilter.pq
- Test_SimplePromoCheck.pq
- Test_CountPromos.pq

### 2. Issues Diagnosed and Fixed

| Issue | Root Cause | Solution |
|-------|------------|----------|
| Date vs DateTime comparison | `#date` vs `#datetime` mismatch | Changed to `#datetime(2022, 1, 1, 0, 0, 0)` |
| Only 23 rows returned | ZP franchise filter excluding promos | Removed `[Franchise] <> "ZP"` from promo filter |
| Wrong descriptions in dim_PromoType | InTrans.Description = customer name | Join with jdis_Part_Information |
| Dataflow write failure (Qty "4B") | Branch column typed as Int64 | Use directly in report with text type |

### 3. Key Discovery: Branch Data Structure

Branch values include sub-branches like:
- 4B, 4S, 4I (all branch 4 variations)
- 4S = setup shop, etc.

**Impact:** Branch must be `type text`, not Int64. The dim_BranchLocation handles the relationship.

### 4. Architecture Decision

**Fact_InTrans_AllPromo:** Use directly in Power BI semantic model (Power Query), NOT as a dataflow → Lakehouse table.

**Rationale:**
- Simple query (just date filter + column selection)
- No complex transformations
- Avoids double storage
- Avoids dataflow write issues with Qty column

---

## New Star Schema Design

```
                     dim_DateTable
                          |
                          |
    dim_PromoType ───> Fact_PartsPromo <─── dim_BranchLocation
          |               |
          |               |
          └───────> dim_RepairOrder
                          |
                          |
                   Fact_InTrans_AllPromo
```

### Relationships

| From | To | Cardinality |
|------|----|-------------|
| Fact_PartsPromo[PART_NO] | dim_PromoType[PromoPartNo] | Many-to-One |
| Fact_PartsPromo[REF_NO] | dim_RepairOrder[REF_NO] | Many-to-One |
| Fact_PartsPromo[Branch] | dim_BranchLocation[BranchID] | Many-to-One |
| Fact_PartsPromo[DateKey] | dim_DateTable[Date] | Many-to-One |
| Fact_InTrans_AllPromo[Branch] | dim_BranchLocation[BranchID] | Many-to-One |
| Fact_InTrans_AllPromo[DateKey] | dim_DateTable[Date] | Many-to-One |

---

## Next Steps

### Phase 1: Testing (Current)

1. **Test dim_PromoType in Fabric**
   - Add to dataflow
   - Verify row counts (~50 rows expected)
   - Confirm descriptions from jdis_Part_Information

2. **Test dim_RepairOrder in Fabric**
   - Add to dataflow
   - Verify aggregations (TotalPartsSales, TotalPromoDiscount)
   - Check performance (may be slow due to Table.ToRecords)

3. **Validate Fact_InTrans_AllPromo in Report**
   - Add to semantic model via Power Query
   - Confirm data loads correctly
   - Test Branch relationship

### Phase 2: Semantic Model

1. Create new semantic model in Fabric
2. Add all tables
3. Configure relationships
4. Test relationship integrity

### Phase 3: DAX Measures

**Measures to Create:**

```dax
-- From old report
Net Sales Value = SUM(Fact_PartsPromo[SaleValue])
Net Cost Value = SUM(Fact_PartsPromo[CostValue])
Total SALE_VAL = SUM(Fact_InTrans_AllPromo[SaleValue])
Percent to Sale Val = DIVIDE([Net Sales Value], [Total SALE_VAL], 0)

-- New measures from dim_RepairOrder
Total Original Sales = SUM(dim_RepairOrder[TotalPartsSales])
Total Discount Amount = SUM(dim_RepairOrder[DiscountAmount])
Avg Discount % = AVERAGE(dim_RepairOrder[DiscountPercent])
```

### Phase 4: Report Visuals

1. Recreate key pages from old report
2. Add new insights enabled by star schema
3. Test with users
4. Deploy to production

---

## Files Reference

### New Report Queries
```
projects/parts promo - report/queries/new report/
├── fact tables/
│   ├── Fact_PartsPromo.pq (original, not used)
│   ├── Fact_PartsPromo_v2.pq (current, in dataflow)
│   ├── Fact_InTrans_AllPromo.pq (dataflow version)
│   └── Fact_InTrans_AllPromo_ForReport.pq (use in report)
├── dimensions/
│   ├── dim_PromoType.pq
│   └── dim_RepairOrder.pq
└── diagnostics/
    ├── Test_PromoFilter.pq
    ├── Test_SimplePromoCheck.pq
    └── Test_CountPromos.pq
```

### Old Report Reference
```
projects/parts promo - report/queries/old report/
├── fact tables/
│   ├── Parts_Promo.pq
│   └── InTrans_All_Promo.pq
```

### Info Exports
```
projects/parts promo - report/info-exports/old report/
├── Parts Promo V2.xlsx
├── Old Report - Parts Promo Tables.csv
├── Old Report - Parts Promo Relationships.csv
├── Old Report - Parts Promo Measures.csv
└── Old Report - Parts Promo Columns.csv
```

---

## Lessons Learned

See: `.claude/guides/LESSONS-LEARNED-PARTS-PROMO.md`

Key takeaways:
1. ZP franchise = promo parts (don't filter out!)
2. Branch column is TEXT (sub-branches like 4B, 4S)
3. InTrans.Description = customer name, not part description
4. Date vs DateTime type comparison must match
5. Simple queries better handled in report Power Query than dataflow

---

## Open Questions

1. **dim_RepairOrder Performance:** Will Table.ToRecords pattern be too slow on large dataset?
2. **Qty Column:** Do we need it? Currently excluded from AllPromo to avoid conversion issues.
3. **PromoCategory Logic:** Are the category groupings in dim_PromoType correct for business needs?

---

## Contact

Project Owner: bfox
Last Working Session: 2026-01-19
