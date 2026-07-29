# CU Usage Report

**Generated:** 2026-07-29 08:01:44
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1285.1 CU |
| Operations | 139 |
| Avg per Operation | 9.2 CU |
| Peak Operation | 36 CU |
| F4 Capacity Used | 55.8% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 106.8 | 35.6 | 3 |
| df_PartsLookup_Sync | 50.4 | 25.2 | 2 |
| df_Fact_Transfers | 47.2 | 23.6 | 2 |
| df_Fact_Parts_Details | 45.2 | 22.6 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_InTrans_PartsCounter_Raw | 38.2 | 19.1 | 2 |
| df_Fact_First_Pass_Fill | 33.2 | 16.6 | 2 |
| df_InHist_PmManage_Raw | 32 | 16 | 2 |
| df_Fact_WorkOrderParts | 31.2 | 15.6 | 2 |
| df_Fact_Service_Detail | 31.2 | 15.6 | 2 |

## Recommendations

- Consider spreading refreshes: 139 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

