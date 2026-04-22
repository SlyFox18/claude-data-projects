# CU Usage Report

**Generated:** 2026-04-22 08:01:28
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1327.3 CU |
| Operations | 119 |
| Avg per Operation | 11.2 CU |
| Peak Operation | 32.2 CU |
| F4 Capacity Used | 57.6% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 94.2 | 31.4 | 3 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_Parts_Details | 59.2 | 29.6 | 2 |
| df_Fact_Inventory | 55.2 | 27.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_Fact_PartSales_24Hours | 40.8 | 13.6 | 3 |
| df_InTrans_PartsCounter_Raw | 40.8 | 20.4 | 2 |
| df_GlTrans_Raw | 35.8 | 17.9 | 2 |
| df_Fact_Invoice_UniqueCustomers | 35.2 | 17.6 | 2 |
| df_Fact_WorkOrderParts | 29.6 | 29.6 | 1 |

## Recommendations

- Consider spreading refreshes: 119 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

