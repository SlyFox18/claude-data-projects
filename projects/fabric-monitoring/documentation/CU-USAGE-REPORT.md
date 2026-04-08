# CU Usage Report

**Generated:** 2026-04-08 08:01:28
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1494.9 CU |
| Operations | 134 |
| Avg per Operation | 11.2 CU |
| Peak Operation | 37.6 CU |
| F4 Capacity Used | 64.9% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_WorkOrderParts | 98.8 | 32.9 | 3 |
| df_JDIS_PART_INFORMATION_Raw | 93 | 31 | 3 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_Service_Detail | 43.2 | 21.6 | 2 |
| df_Fact_Parts_Invoices | 43.2 | 21.6 | 2 |
| df_Fact_PartSales_24Hours | 40.8 | 13.6 | 3 |
| df_InTrans_PartsCounter_Raw | 40.8 | 20.4 | 2 |
| df_Invoice_Raw | 40.8 | 20.4 | 2 |
| df_GlTrans_Raw | 35.8 | 17.9 | 2 |
| df_Fact_LaborJobSummary | 35.2 | 17.6 | 2 |

## Recommendations

- WARNING: Using 64.9% of F4 capacity - monitor closely
- Consider spreading refreshes: 134 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

