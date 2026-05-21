# CU Usage Report

**Generated:** 2026-05-21 08:01:47
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1406.4 CU |
| Operations | 128 |
| Avg per Operation | 11 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 61% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 129.2 | 25.8 | 5 |
| df_Fact_Parts_Invoices | 59.2 | 19.7 | 3 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_Fact_Transfers | 47.2 | 23.6 | 2 |
| df_InTrans_PartsCounter_Raw | 47 | 23.5 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_GlTrans_Raw | 37 | 18.5 | 2 |
| df_Fact_Invoice_UniqueCustomers | 35.2 | 17.6 | 2 |
| df_Fact_LaborJobSummary | 35.2 | 17.6 | 2 |
| df_Fact_PartSales_24Hours | 34.8 | 11.6 | 3 |

## Recommendations

- WARNING: Using 61% of F4 capacity - monitor closely
- Consider spreading refreshes: 128 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

