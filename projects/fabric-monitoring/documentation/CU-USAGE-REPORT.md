# CU Usage Report

**Generated:** 2026-05-01 08:01:29
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1418 CU |
| Operations | 137 |
| Avg per Operation | 10.4 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 61.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 99.2 | 33.1 | 3 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_Fact_Service_Detail | 47.2 | 23.6 | 2 |
| df_InTrans_PartsCounter_Raw | 47 | 23.5 | 2 |
| df_Fact_LaborJobSummary | 40.8 | 13.6 | 3 |
| df_GlTrans_Raw | 40.8 | 20.4 | 2 |
| df_Fact_Parts_Invoices | 37.2 | 18.6 | 2 |
| df_InHist_PmManage_Raw | 37 | 18.5 | 2 |
| df_Dim_Part | 29.4 | 14.7 | 2 |
| df_Fact_Invoice_UniqueCustomers | 29.2 | 14.6 | 2 |

## Recommendations

- WARNING: Using 61.5% of F4 capacity - monitor closely
- Consider spreading refreshes: 137 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

