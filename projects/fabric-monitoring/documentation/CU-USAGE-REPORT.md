# CU Usage Report

**Generated:** 2026-03-04 06:01:43
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 953.4 CU |
| Operations | 86 |
| Avg per Operation | 11.1 CU |
| Peak Operation | 59.6 CU |
| F4 Capacity Used | 41.4% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_WorkOrderParts | 83.2 | 41.6 | 2 |
| df_Fact_Invoice_UniqueCustomers | 73.2 | 36.6 | 2 |
| df_InHist_PmManage_Raw | 47 | 6.7 | 7 |
| df_Fact_Inventory | 43.6 | 43.6 | 1 |
| df_Invoice_Raw | 40 | 8 | 5 |
| df_FactPartTransactions_Incremental | 33.2 | 16.6 | 2 |
| df_JDIS_PART_INFORMATION_Raw | 32.8 | 8.2 | 4 |
| DF_PartMaster_Snapshot_Daily | 32.4 | 16.2 | 2 |
| df_GlTrans_Raw | 29.8 | 5 | 6 |
| df_WKROFILE_Raw | 27.8 | 6.9 | 4 |

## Recommendations

- Consider spreading refreshes: 35 operations at hour 10

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

