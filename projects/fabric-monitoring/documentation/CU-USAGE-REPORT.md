# CU Usage Report

**Generated:** 2026-03-02 06:01:39
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 597.6 CU |
| Operations | 50 |
| Avg per Operation | 12 CU |
| Peak Operation | 67.6 CU |
| F4 Capacity Used | 25.9% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_WorkOrderParts | 67.6 | 67.6 | 1 |
| df_Fact_Invoice_UniqueCustomers | 55.6 | 55.6 | 1 |
| df_Fact_LaborJobSummary | 51.6 | 51.6 | 1 |
| df_Fact_First_Pass_Fill | 45.6 | 45.6 | 1 |
| df_Invoice_Raw | 43.5 | 7.2 | 6 |
| df_JDIS_PART_INFORMATION_Raw | 38.5 | 7.7 | 5 |
| df_InHist_PmManage_Raw | 33.8 | 6.8 | 5 |
| DF_PartMaster_Snapshot_Daily | 30.9 | 15.4 | 2 |
| df_GlTrans_Raw | 27.8 | 6.9 | 4 |
| df_WKROFILE_Raw | 19.2 | 6.4 | 3 |

## Recommendations

- Consider spreading refreshes: 21 operations at hour 9

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

