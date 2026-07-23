# CU Usage Report

**Generated:** 2026-07-23 08:01:32
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1546.6 CU |
| Operations | 138 |
| Avg per Operation | 11.2 CU |
| Peak Operation | 42.2 CU |
| F4 Capacity Used | 67.1% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 115.5 | 38.5 | 3 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_Parts_Details | 53.2 | 26.6 | 2 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_InTrans_PartsCounter_Raw | 50.8 | 25.4 | 2 |
| df_TechnicianPunchedTime_Raw | 47.5 | 15.8 | 3 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_Fact_PartSales_24Hours | 38.8 | 12.9 | 3 |
| df_GlTrans_Raw | 38.2 | 19.1 | 2 |
| df_Fact_Parts_Invoices | 37.2 | 18.6 | 2 |

## Recommendations

- WARNING: Using 67.1% of F4 capacity - monitor closely
- Consider spreading refreshes: 138 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

