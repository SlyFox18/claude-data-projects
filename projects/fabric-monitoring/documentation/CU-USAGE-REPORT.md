# CU Usage Report

**Generated:** 2026-07-07 08:01:37
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1443 CU |
| Operations | 135 |
| Avg per Operation | 10.7 CU |
| Peak Operation | 37.2 CU |
| F4 Capacity Used | 62.6% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 103 | 34.3 | 3 |
| df_Fact_WorkOrderParts | 61.2 | 30.6 | 2 |
| df_Fact_Parts_Invoices | 58.8 | 19.6 | 3 |
| df_Fact_Service_Detail | 47.2 | 23.6 | 2 |
| df_Invoice_Raw | 44.5 | 22.2 | 2 |
| df_InTrans_PartsCounter_Raw | 42 | 21 | 2 |
| df_Fact_PartSales_24Hours | 38.8 | 12.9 | 3 |
| df_GlTrans_Raw | 34.5 | 17.2 | 2 |
| df_InHist_PmManage_Raw | 33.2 | 16.6 | 2 |
| df_Fact_Service_Invoices | 31.6 | 31.6 | 1 |

## Recommendations

- WARNING: Using 62.6% of F4 capacity - monitor closely
- Consider spreading refreshes: 135 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

