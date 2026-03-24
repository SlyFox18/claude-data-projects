# CU Usage Report

**Generated:** 2026-03-24 08:01:27
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1924.9 CU |
| Operations | 179 |
| Avg per Operation | 10.8 CU |
| Peak Operation | 39.6 CU |
| F4 Capacity Used | 83.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 137.2 | 22.9 | 6 |
| df_Fact_WorkOrderParts | 75.2 | 37.6 | 2 |
| df_Invoice_Raw | 62.5 | 12.5 | 5 |
| df_Fact_Parts_Details | 59.2 | 29.6 | 2 |
| df_Fact_Service_Invoices | 59.2 | 29.6 | 2 |
| df_Fact_Inventory | 55.2 | 27.6 | 2 |
| df_InTrans_PartsCounter_Raw | 55 | 11 | 5 |
| df_InHist_PmManage_Raw | 52.5 | 10.5 | 5 |
| df_GlTrans_Raw | 50 | 10 | 5 |
| df_Fact_Service_Detail | 49.2 | 24.6 | 2 |

## Recommendations

- CRITICAL: Using 83.5% of F4 capacity - consider upgrading to F8 or F16
- Consider spreading refreshes: 133 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

