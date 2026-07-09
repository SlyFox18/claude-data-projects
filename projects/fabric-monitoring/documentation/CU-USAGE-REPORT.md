# CU Usage Report

**Generated:** 2026-07-09 08:01:41
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1450.5 CU |
| Operations | 140 |
| Avg per Operation | 10.4 CU |
| Peak Operation | 42.2 CU |
| F4 Capacity Used | 63% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 107.8 | 26.9 | 4 |
| df_Fact_Service_Invoices | 63.2 | 31.6 | 2 |
| df_Fact_Parts_Details | 61.2 | 30.6 | 2 |
| df_Fact_Service_Detail | 47.2 | 23.6 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_GlTrans_Raw | 39.5 | 19.8 | 2 |
| df_Fact_PartSales_24Hours | 36.8 | 12.3 | 3 |
| df_InHist_PmManage_Raw | 34.5 | 17.2 | 2 |
| df_Fact_WorkOrderParts | 29.6 | 29.6 | 1 |
| df_Dim_Part | 29.4 | 14.7 | 2 |

## Recommendations

- WARNING: Using 63% of F4 capacity - monitor closely
- Consider spreading refreshes: 140 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

