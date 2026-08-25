# CU Usage Report

**Generated:** 2026-08-25 08:01:39
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 817.8 CU |
| Operations | 98 |
| Avg per Operation | 8.3 CU |
| Peak Operation | 37.2 CU |
| F4 Capacity Used | 35.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 96.2 | 19.2 | 5 |
| df_InMaster_PartsLookup_Raw | 83.2 | 6.9 | 12 |
| df_Invoice_Raw | 37.8 | 9.4 | 4 |
| df_InTrans_PartsCounter_Raw | 34 | 8.5 | 4 |
| df_GlTrans_Raw | 32.8 | 8.2 | 4 |
| df_InHist_PmManage_Raw | 31.5 | 7.9 | 4 |
| df_WKROFILE_Raw | 29 | 7.2 | 4 |
| df_Dim_Part | 25.2 | 25.2 | 1 |
| df_Fact_WorkOrderParts | 23.6 | 23.6 | 1 |
| df_Fact_Parts_Details | 21.6 | 21.6 | 1 |

## Recommendations

- Consider spreading refreshes: 98 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

