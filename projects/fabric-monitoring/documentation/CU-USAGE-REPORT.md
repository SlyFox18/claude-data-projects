# CU Usage Report

**Generated:** 2026-04-14 08:01:31
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 2889.4 CU |
| Operations | 135 |
| Avg per Operation | 21.4 CU |
| Peak Operation | 1948 CU |
| F4 Capacity Used | 125.4% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_GlTrans_Full_Raw | 1492.2 | 373.1 | 4 |
| df_JDIS_PART_INFORMATION_Raw | 101.8 | 33.9 | 3 |
| df_Fact_Transfers | 51.2 | 25.6 | 2 |
| df_InTrans_PartsCounter_Raw | 44.5 | 22.2 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_Fact_Parts_Invoices | 39.2 | 19.6 | 2 |
| df_Fact_Invoice_UniqueCustomers | 33.2 | 16.6 | 2 |
| df_InHist_PmManage_Raw | 30.8 | 15.4 | 2 |
| df_Fact_Service_Invoices | 29.6 | 29.6 | 1 |
| df_Fact_WorkOrderParts | 29.6 | 29.6 | 1 |

## Recommendations

- High CU Dataflows: Review query complexity for: df_GlTrans_Full_Raw
- CRITICAL: Using 125.4% of F4 capacity - consider upgrading to F8 or F16
- Consider spreading refreshes: 135 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

