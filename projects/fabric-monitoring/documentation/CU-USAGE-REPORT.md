# CU Usage Report

**Generated:** 2026-03-17 06:01:25
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1165.1 CU |
| Operations | 93 |
| Avg per Operation | 12.5 CU |
| Peak Operation | 65.6 CU |
| F4 Capacity Used | 50.6% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_WorkOrderParts | 83.2 | 41.6 | 2 |
| df_Invoice_Raw | 67.2 | 11.2 | 6 |
| df_JDIS_PART_INFORMATION_Raw | 66.2 | 13.2 | 5 |
| df_FactPartTransactions_Incremental | 65.6 | 65.6 | 1 |
| df_InTrans_PartsCounter_Raw | 57.2 | 9.5 | 6 |
| df_Fact_PartSales_24Hours | 48.8 | 16.3 | 3 |
| df_InHist_PmManage_Raw | 43.8 | 8.8 | 5 |
| df_InTrans_Incremental | 42.3 | 10.6 | 4 |
| df_Fact_Inventory | 37.6 | 37.6 | 1 |
| DF_PartMaster_Snapshot_Daily | 36.9 | 18.4 | 2 |

## Recommendations

- Consider spreading refreshes: 42 operations at hour 9

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

