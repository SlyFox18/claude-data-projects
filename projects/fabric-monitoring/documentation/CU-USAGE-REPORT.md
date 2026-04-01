# CU Usage Report

**Generated:** 2026-04-01 08:01:35
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1466.3 CU |
| Operations | 133 |
| Avg per Operation | 11 CU |
| Peak Operation | 33.6 CU |
| F4 Capacity Used | 63.6% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 121.5 | 30.4 | 4 |
| df_Fact_Service_Invoices | 59.2 | 29.6 | 2 |
| df_Fact_Parts_Details | 53.2 | 26.6 | 2 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_Fact_Service_Detail | 45.2 | 22.6 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_GlTrans_Raw | 40.8 | 20.4 | 2 |
| df_InTrans_PartsCounter_Raw | 39.5 | 19.8 | 2 |
| df_Fact_Parts_Invoices | 39.2 | 19.6 | 2 |
| df_Fact_LaborJobSummary | 37.2 | 18.6 | 2 |

## Recommendations

- WARNING: Using 63.6% of F4 capacity - monitor closely
- Consider spreading refreshes: 133 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

