# CU Usage Report

**Generated:** 2026-04-09 08:01:22
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1417.4 CU |
| Operations | 124 |
| Avg per Operation | 11.4 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 61.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 99.5 | 24.9 | 4 |
| df_Fact_WorkOrderParts | 63.2 | 31.6 | 2 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_Parts_Details | 55.2 | 27.6 | 2 |
| df_Fact_Transfers | 47.2 | 23.6 | 2 |
| df_InTrans_PartsCounter_Raw | 44.5 | 22.2 | 2 |
| df_Fact_Service_Detail | 43.2 | 21.6 | 2 |
| df_Fact_PartSales_24Hours | 42.8 | 14.3 | 3 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_Fact_LaborJobSummary | 37.2 | 18.6 | 2 |

## Recommendations

- WARNING: Using 61.5% of F4 capacity - monitor closely
- Consider spreading refreshes: 124 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

