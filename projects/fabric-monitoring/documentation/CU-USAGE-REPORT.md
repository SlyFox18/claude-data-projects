# CU Usage Report

**Generated:** 2026-03-16 06:01:32
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 571.9 CU |
| Operations | 52 |
| Avg per Operation | 11 CU |
| Peak Operation | 53.6 CU |
| F4 Capacity Used | 24.8% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_WorkOrderParts | 83.2 | 41.6 | 2 |
| df_JDIS_PART_INFORMATION_Raw | 66.2 | 13.2 | 5 |
| df_WKROFILE_Raw | 46 | 7.7 | 6 |
| df_Invoice_Raw | 42.5 | 8.5 | 5 |
| DF_PartMaster_Snapshot_Daily | 33.9 | 17 | 2 |
| df_Fact_Parts_Details | 31.6 | 31.6 | 1 |
| df_Fact_Parts_Invoices | 23.6 | 23.6 | 1 |
| df_Fact_First_Pass_Fill | 19.6 | 19.6 | 1 |
| df_InHist_PmManage_Raw | 19.2 | 6.4 | 3 |
| df_Dim_Part | 16.2 | 16.2 | 1 |

## Recommendations

- Consider spreading refreshes: 24 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

