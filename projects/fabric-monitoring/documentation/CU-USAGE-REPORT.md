# CU Usage Report

**Generated:** 2026-04-07 08:01:30
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1296.9 CU |
| Operations | 122 |
| Avg per Operation | 10.6 CU |
| Peak Operation | 37.6 CU |
| F4 Capacity Used | 56.3% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 89.2 | 29.8 | 3 |
| df_Fact_Transfers | 51.2 | 25.6 | 2 |
| df_Fact_Service_Detail | 43.2 | 21.6 | 2 |
| df_Fact_Parts_Invoices | 41.2 | 20.6 | 2 |
| df_Invoice_Raw | 39.5 | 19.8 | 2 |
| df_InTrans_PartsCounter_Raw | 38.2 | 19.1 | 2 |
| df_Fact_WorkOrderParts | 37.6 | 37.6 | 1 |
| df_Fact_First_Pass_Fill | 35.2 | 17.6 | 2 |
| df_Dim_Part | 30.9 | 15.4 | 2 |
| df_GlTrans_Raw | 30.8 | 15.4 | 2 |

## Recommendations

- Consider spreading refreshes: 122 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

