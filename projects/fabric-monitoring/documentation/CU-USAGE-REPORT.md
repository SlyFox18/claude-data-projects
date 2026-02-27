# CU Usage Report

**Generated:** 2026-02-26 06:01:59
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 702.2 CU |
| Operations | 61 |
| Avg per Operation | 11.5 CU |
| Peak Operation | 111.6 CU |
| F4 Capacity Used | 30.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_WorkOrderParts | 111.6 | 111.6 | 1 |
| df_FactPartTransactions_Incremental | 77.6 | 77.6 | 1 |
| df_Fact_Transfers | 71.2 | 35.6 | 2 |
| df_JDIS_PART_INFORMATION_Raw | 51.5 | 10.3 | 5 |
| df_InHist_PmManage_Raw | 36 | 4.5 | 8 |
| df_Fact_Inventory | 35.6 | 35.6 | 1 |
| DF_PartMaster_Snapshot_Daily | 30.9 | 15.4 | 2 |
| df_InTrans_Incremental | 21.9 | 11 | 2 |
| df_Fact_Service_Parts_Detail | 21.6 | 21.6 | 1 |
| df_Dim_Part | 20.7 | 20.7 | 1 |

## Recommendations

- High CU Dataflows: Review query complexity for: df_Fact_WorkOrderParts
- Consider spreading refreshes: 31 operations at hour 9

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

