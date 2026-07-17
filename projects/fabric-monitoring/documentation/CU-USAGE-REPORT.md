# CU Usage Report

**Generated:** 2026-07-17 08:01:31
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1627.8 CU |
| Operations | 151 |
| Avg per Operation | 10.8 CU |
| Peak Operation | 39.8 CU |
| F4 Capacity Used | 70.7% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 103 | 34.3 | 3 |
| df_PartsLookup_Sync | 96.3 | 24.1 | 4 |
| df_Fact_Inventory | 58 | 29 | 2 |
| df_Fact_WorkOrderParts | 57.2 | 28.6 | 2 |
| df_InTrans_PartsCounter_Raw | 49.5 | 24.8 | 2 |
| df_Fact_Service_Detail | 47.2 | 23.6 | 2 |
| df_Invoice_Raw | 45.8 | 22.9 | 2 |
| df_Fact_Transfers | 45.2 | 22.6 | 2 |
| df_GlTrans_Raw | 40.8 | 20.4 | 2 |
| df_Fact_Parts_Invoices | 37.2 | 18.6 | 2 |

## Recommendations

- WARNING: Using 70.7% of F4 capacity - monitor closely
- Consider spreading refreshes: 151 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

