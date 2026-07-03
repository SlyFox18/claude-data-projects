# CU Usage Report

**Generated:** 2026-07-03 08:01:44
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1470.9 CU |
| Operations | 133 |
| Avg per Operation | 11.1 CU |
| Peak Operation | 43.5 CU |
| F4 Capacity Used | 63.8% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 124.2 | 41.4 | 3 |
| df_Fact_Service_Invoices | 65.2 | 32.6 | 2 |
| df_Fact_Parts_Details | 59.2 | 29.6 | 2 |
| df_Fact_Transfers | 47.2 | 23.6 | 2 |
| df_InTrans_PartsCounter_Raw | 47 | 23.5 | 2 |
| df_Invoice_Raw | 44.5 | 22.2 | 2 |
| df_GlTrans_Raw | 35.8 | 17.9 | 2 |
| df_Fact_First_Pass_Fill | 35.2 | 17.6 | 2 |
| df_InHist_PmManage_Raw | 33.2 | 16.6 | 2 |
| df_Fact_WorkOrderParts | 31.6 | 31.6 | 1 |

## Recommendations

- WARNING: Using 63.8% of F4 capacity - monitor closely
- Consider spreading refreshes: 133 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

