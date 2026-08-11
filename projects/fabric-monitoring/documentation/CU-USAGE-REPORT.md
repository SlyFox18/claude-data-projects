# CU Usage Report

**Generated:** 2026-08-11 08:01:43
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1226 CU |
| Operations | 156 |
| Avg per Operation | 7.9 CU |
| Peak Operation | 143.6 CU |
| F4 Capacity Used | 53.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_Transfers | 608.4 | 67.6 | 9 |
| df_Fact_WorkOrderParts | 132.8 | 44.3 | 3 |
| df_JDIS_PART_INFORMATION_Raw | 114.2 | 38.1 | 3 |
| df_Fact_InTrans_UniqueCustomers | 72.8 | 24.3 | 3 |
| df_Invoice_Raw | 44.5 | 22.2 | 2 |
| df_Fact_Service_Detail | 42.8 | 14.3 | 3 |
| df_Fact_Parts_Invoices | 40.8 | 13.6 | 3 |
| df_InTrans_PartsCounter_Raw | 40.8 | 20.4 | 2 |
| df_Fact_PartSales_24Hours | 40.4 | 10.1 | 4 |
| df_GlTrans_Raw | 35.8 | 17.9 | 2 |

## Recommendations

- Consider spreading refreshes: 156 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

