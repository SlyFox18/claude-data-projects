# CU Usage Report

**Generated:** 2026-06-30 08:01:40
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1439.2 CU |
| Operations | 135 |
| Avg per Operation | 10.7 CU |
| Peak Operation | 37.2 CU |
| F4 Capacity Used | 62.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 109.2 | 36.4 | 3 |
| df_Fact_WorkOrderParts | 63.2 | 31.6 | 2 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_Fact_Service_Detail | 45.2 | 22.6 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_InTrans_PartsCounter_Raw | 42 | 21 | 2 |
| df_Fact_LaborJobSummary | 37.2 | 18.6 | 2 |
| df_Fact_ServiceTimeSheet_Audit | 35.2 | 17.6 | 2 |
| df_GlTrans_Raw | 34.5 | 17.2 | 2 |
| df_Fact_Service_Invoices | 33.6 | 33.6 | 1 |

## Recommendations

- WARNING: Using 62.5% of F4 capacity - monitor closely
- Consider spreading refreshes: 135 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

