# CU Usage Report

**Generated:** 2026-06-03 08:01:36
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1487.2 CU |
| Operations | 135 |
| Avg per Operation | 11 CU |
| Peak Operation | 32.2 CU |
| F4 Capacity Used | 64.6% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 102.8 | 25.7 | 4 |
| df_Fact_Service_Invoices | 63.2 | 31.6 | 2 |
| df_Fact_Parts_Details | 59.2 | 29.6 | 2 |
| df_Fact_Inventory | 53.2 | 26.6 | 2 |
| df_Invoice_Raw | 44.5 | 22.2 | 2 |
| df_Fact_Service_Detail | 43.2 | 21.6 | 2 |
| df_InTrans_PartsCounter_Raw | 40.8 | 20.4 | 2 |
| df_GlTrans_Raw | 35.8 | 17.9 | 2 |
| df_Fact_LaborJobSummary | 33.2 | 16.6 | 2 |
| df_Fact_Invoice_UniqueCustomers | 33.2 | 16.6 | 2 |

## Recommendations

- WARNING: Using 64.6% of F4 capacity - monitor closely
- Consider spreading refreshes: 135 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

