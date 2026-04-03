# CU Usage Report

**Generated:** 2026-04-03 08:01:23
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1527.1 CU |
| Operations | 126 |
| Avg per Operation | 12.1 CU |
| Peak Operation | 122.4 CU |
| F4 Capacity Used | 66.3% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_WorkOrderParts | 160 | 80 | 2 |
| df_JDIS_PART_INFORMATION_Raw | 131.8 | 26.4 | 5 |
| df_Invoice_Raw | 79.2 | 19.8 | 4 |
| df_InTrans_PartsCounter_Raw | 61.8 | 20.6 | 3 |
| df_GlTrans_Raw | 60.5 | 20.2 | 3 |
| df_WKROFILE_Raw | 35.5 | 11.8 | 3 |
| df_Fact_MDInvoices_Closed | 34.8 | 11.6 | 3 |
| df_InHist_PmManage_Raw | 32 | 16 | 2 |
| df_Fact_Service_Invoices | 29.6 | 29.6 | 1 |
| df_Fact_Parts_Details | 29.6 | 29.6 | 1 |

## Recommendations

- WARNING: Using 66.3% of F4 capacity - monitor closely
- Consider spreading refreshes: 126 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

