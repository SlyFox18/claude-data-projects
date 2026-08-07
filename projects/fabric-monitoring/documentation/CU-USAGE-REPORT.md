# CU Usage Report

**Generated:** 2026-08-07 08:01:41
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1556.8 CU |
| Operations | 139 |
| Avg per Operation | 11.2 CU |
| Peak Operation | 63.6 CU |
| F4 Capacity Used | 67.6% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_Transfers | 187.2 | 37.4 | 5 |
| df_JDIS_PART_INFORMATION_Raw | 114.2 | 38.1 | 3 |
| df_Fact_WorkOrderParts | 85.2 | 42.6 | 2 |
| df_Fact_InTrans_UniqueCustomers | 47.2 | 23.6 | 2 |
| df_PartsLookup_Sync_Incremental | 45.3 | 11.3 | 4 |
| df_Invoice_Raw | 44.5 | 22.2 | 2 |
| df_InTrans_PartsCounter_Raw | 42 | 21 | 2 |
| df_GlTrans_Raw | 37 | 18.5 | 2 |
| df_Fact_PartSales_24Hours | 34.8 | 11.6 | 3 |
| df_InHist_PmManage_Raw | 34.5 | 17.2 | 2 |

## Recommendations

- WARNING: Using 67.6% of F4 capacity - monitor closely
- Consider spreading refreshes: 139 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

