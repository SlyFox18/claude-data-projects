# CU Usage Report

**Generated:** 2026-04-10 08:01:24
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1408.8 CU |
| Operations | 128 |
| Avg per Operation | 11 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 61.1% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 100.8 | 25.2 | 4 |
| df_Fact_WorkOrderParts | 61.2 | 30.6 | 2 |
| df_Fact_Service_Invoices | 59.2 | 29.6 | 2 |
| df_InTrans_PartsCounter_Raw | 43.2 | 21.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_Fact_PartSales_24Hours | 40.8 | 13.6 | 3 |
| df_Fact_Parts_Invoices | 39.2 | 19.6 | 2 |
| df_Fact_LaborJobSummary | 35.2 | 17.6 | 2 |
| df_Fact_First_Pass_Fill | 35.2 | 17.6 | 2 |
| df_UniqueCustomer_Lookup | 35.1 | 11.7 | 3 |

## Recommendations

- WARNING: Using 61.1% of F4 capacity - monitor closely
- Consider spreading refreshes: 128 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

