# CU Usage Report

**Generated:** 2026-03-09 06:01:38
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 518.1 CU |
| Operations | 54 |
| Avg per Operation | 9.6 CU |
| Peak Operation | 61.6 CU |
| F4 Capacity Used | 22.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_Service_Detail | 65.2 | 32.6 | 2 |
| df_JDIS_PART_INFORMATION_Raw | 51.2 | 10.2 | 5 |
| df_InTrans_PartsCounter_Raw | 39.8 | 6.6 | 6 |
| df_WKROFILE_Raw | 39.8 | 6.6 | 6 |
| df_Fact_Inventory | 39.6 | 39.6 | 1 |
| df_Fact_Parts_Details | 37.6 | 37.6 | 1 |
| DF_PartMaster_Snapshot_Daily | 35.4 | 17.7 | 2 |
| df_Invoice_Raw | 25.2 | 6.3 | 4 |
| df_Parts_InterbranchTransfer_Raw | 24.8 | 4.1 | 6 |
| df_InHist_PmManage_Raw | 23 | 7.7 | 3 |

## Recommendations

- Consider spreading refreshes: 32 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

