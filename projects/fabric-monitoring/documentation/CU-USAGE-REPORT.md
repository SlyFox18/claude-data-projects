# CU Usage Report

**Generated:** 2026-07-16 08:01:36
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1636.3 CU |
| Operations | 142 |
| Avg per Operation | 11.5 CU |
| Peak Operation | 67.6 CU |
| F4 Capacity Used | 71% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_PartsLookup_Sync | 166.2 | 27.7 | 6 |
| df_JDIS_PART_INFORMATION_Raw | 113 | 37.7 | 3 |
| df_Fact_PartSales_24Hours | 88.8 | 29.6 | 3 |
| df_GlTrans_Raw | 55.5 | 18.5 | 3 |
| df_Fact_Parts_Details | 55.2 | 27.6 | 2 |
| df_Fact_WorkOrderParts | 55.2 | 27.6 | 2 |
| df_InMaster_PartsLookup_Raw | 53.2 | 7.6 | 7 |
| df_Fact_Inventory | 49.2 | 24.6 | 2 |
| df_InTrans_PartsCounter_Raw | 47 | 23.5 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |

## Recommendations

- WARNING: Using 71% of F4 capacity - monitor closely
- Consider spreading refreshes: 142 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

