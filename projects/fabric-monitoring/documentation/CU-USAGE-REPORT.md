# CU Usage Report

**Generated:** 2026-08-06 08:01:41
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1446.8 CU |
| Operations | 111 |
| Avg per Operation | 13 CU |
| Peak Operation | 154.2 CU |
| F4 Capacity Used | 62.8% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_InTrans_Incremental | 408.9 | 45.4 | 9 |
| df_JDIS_PART_INFORMATION_Raw | 111.8 | 37.2 | 3 |
| df_Fact_Transfers | 63.6 | 21.2 | 3 |
| df_Fact_WorkOrderParts | 43.6 | 43.6 | 1 |
| df_InTrans_PartsCounter_Raw | 43.2 | 21.6 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_GlTrans_Raw | 37 | 18.5 | 2 |
| df_InHist_PmManage_Raw | 33.2 | 16.6 | 2 |
| df_WKROFILE_Raw | 27 | 13.5 | 2 |
| df_Fact_Parts_Details | 25.6 | 25.6 | 1 |

## Recommendations

- WARNING: Using 62.8% of F4 capacity - monitor closely
- Consider spreading refreshes: 111 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

