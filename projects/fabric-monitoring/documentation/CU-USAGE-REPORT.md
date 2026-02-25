# CU Usage Report

**Generated:** 2026-02-25 06:02:00
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 574.8 CU |
| Operations | 69 |
| Avg per Operation | 8.3 CU |
| Peak Operation | 81.6 CU |
| F4 Capacity Used | 24.9% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_WorkOrderParts | 157.2 | 78.6 | 2 |
| df_InTrans_PartsCounter_Raw | 75 | 7.5 | 10 |
| df_InHist_PmManage_Raw | 37.5 | 4.2 | 9 |
| df_JDIS_PART_INFORMATION_Raw | 24.2 | 4 | 6 |
| df_Invoice_Raw | 22.8 | 2.8 | 8 |
| df_Dim_Part | 22.2 | 22.2 | 1 |
| DF_PartMaster_Snapshot_Daily | 20.4 | 10.2 | 2 |
| df_Fact_CustomerPerformance | 17.6 | 17.6 | 1 |
| df_UniqueCustomer_Lookup | 16.2 | 16.2 | 1 |
| df_Fact_Service_Parts_Detail | 15.6 | 15.6 | 1 |

## Recommendations

- Consider spreading refreshes: 40 operations at hour 9

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

