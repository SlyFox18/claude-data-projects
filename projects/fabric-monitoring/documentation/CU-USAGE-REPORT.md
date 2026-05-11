# CU Usage Report

**Generated:** 2026-05-11 08:01:34
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 884.6 CU |
| Operations | 80 |
| Avg per Operation | 11.1 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 38.4% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 68.2 | 22.8 | 3 |
| df_Fact_WorkOrderParts | 29.6 | 29.6 | 1 |
| df_Fact_Service_Invoices | 29.6 | 29.6 | 1 |
| df_Fact_Parts_Details | 27.6 | 27.6 | 1 |
| df_Fact_Inventory | 25.6 | 25.6 | 1 |
| df_InTrans_PartsCounter_Raw | 24.8 | 24.8 | 1 |
| df_Fact_Transfers | 23.6 | 23.6 | 1 |
| df_GlTrans_Raw | 22.2 | 22.2 | 1 |
| df_Invoice_Raw | 22.2 | 22.2 | 1 |
| df_Fact_Service_Detail | 21.6 | 21.6 | 1 |

## Recommendations

- Consider spreading refreshes: 80 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

