# CU Usage Report

**Generated:** 2026-07-08 08:01:35
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1516.9 CU |
| Operations | 149 |
| Avg per Operation | 10.2 CU |
| Peak Operation | 34.8 CU |
| F4 Capacity Used | 65.8% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 103 | 34.3 | 3 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_Fact_Service_Detail | 49.2 | 24.6 | 2 |
| df_InTrans_PartsCounter_Raw | 43.2 | 21.6 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_GlTrans_Raw | 38.2 | 19.1 | 2 |
| df_Fact_Parts_Invoices | 35.2 | 17.6 | 2 |
| df_Fact_PartSales_24Hours | 34.8 | 11.6 | 3 |
| df_InHist_PmManage_Raw | 34.5 | 17.2 | 2 |
| df_Fact_LaborJobSummary | 33.2 | 16.6 | 2 |

## Recommendations

- WARNING: Using 65.8% of F4 capacity - monitor closely
- Consider spreading refreshes: 149 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

