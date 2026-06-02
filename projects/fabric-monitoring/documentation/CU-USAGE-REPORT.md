# CU Usage Report

**Generated:** 2026-06-02 08:01:39
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 2070.9 CU |
| Operations | 183 |
| Avg per Operation | 11.3 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 89.9% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 137.8 | 34.4 | 4 |
| df_Invoice_Raw | 90.2 | 22.6 | 4 |
| df_InTrans_PartsCounter_Raw | 78 | 26 | 3 |
| df_Fact_Service_Invoices | 63.2 | 31.6 | 2 |
| df_GlTrans_Raw | 60.5 | 20.2 | 3 |
| df_Fact_WorkOrderParts | 59.2 | 29.6 | 2 |
| df_Fact_Parts_Details | 59.2 | 29.6 | 2 |
| df_Fact_Inventory | 53.2 | 26.6 | 2 |
| df_Fact_Transfers | 49.2 | 24.6 | 2 |
| df_WKROFILE_Raw | 47.8 | 11.9 | 4 |

## Recommendations

- CRITICAL: Using 89.9% of F4 capacity - consider upgrading to F8 or F16
- Consider spreading refreshes: 183 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

