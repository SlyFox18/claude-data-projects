# CU Usage Report

**Generated:** 2026-04-15 08:01:35
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 3596.4 CU |
| Operations | 126 |
| Avg per Operation | 28.5 CU |
| Peak Operation | 2282.2 CU |
| F4 Capacity Used | 156.1% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_GlTrans_Full_Raw | 2282.2 | 2282.2 | 1 |
| df_JDIS_PART_INFORMATION_Raw | 63.2 | 31.6 | 2 |
| df_Fact_Service_Invoices | 57.2 | 28.6 | 2 |
| df_Fact_Parts_Details | 53.2 | 26.6 | 2 |
| df_InTrans_PartsCounter_Raw | 48.2 | 24.1 | 2 |
| df_Fact_Service_Detail | 45.2 | 22.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_Fact_Parts_Invoices | 39.2 | 19.6 | 2 |
| df_InHist_PmManage_Raw | 30.8 | 15.4 | 2 |
| df_Fact_WorkOrderParts | 29.6 | 29.6 | 1 |

## Recommendations

- High CU Dataflows: Review query complexity for: df_GlTrans_Full_Raw
- CRITICAL: Using 156.1% of F4 capacity - consider upgrading to F8 or F16
- Consider spreading refreshes: 126 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

