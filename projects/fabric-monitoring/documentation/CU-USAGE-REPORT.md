# CU Usage Report

**Generated:** 2026-04-16 08:01:36
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 2399.8 CU |
| Operations | 57 |
| Avg per Operation | 42.1 CU |
| Peak Operation | 1717.8 CU |
| F4 Capacity Used | 104.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_GlTrans_Full_Raw | 1717.8 | 1717.8 | 1 |
| df_JDIS_PART_INFORMATION_Raw | 130.5 | 26.1 | 5 |
| df_Invoice_Raw | 39.5 | 19.8 | 2 |
| df_GlTrans_Raw | 34.5 | 17.2 | 2 |
| df_InHist_PmManage_Raw | 30.8 | 15.4 | 2 |
| df_Fact_WorkOrderParts | 29.6 | 29.6 | 1 |
| df_InTrans_PartsCounter_Raw | 28.5 | 28.5 | 1 |
| df_WKROFILE_Raw | 23.2 | 11.6 | 2 |
| df_Fact_Service_Detail | 21.6 | 21.6 | 1 |
| df_Fact_Parts_Invoices | 19.6 | 19.6 | 1 |

## Recommendations

- High CU Dataflows: Review query complexity for: df_GlTrans_Full_Raw
- CRITICAL: Using 104.2% of F4 capacity - consider upgrading to F8 or F16
- Consider spreading refreshes: 57 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

