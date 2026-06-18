# CU Usage Report

**Generated:** 2026-06-18 08:01:33
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1653.1 CU |
| Operations | 154 |
| Avg per Operation | 10.7 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 71.8% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 132.8 | 26.6 | 5 |
| df_Fact_ServiceTimeSheet_Audit | 121.2 | 13.5 | 9 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_WorkOrderParts | 59.2 | 29.6 | 2 |
| df_Fact_Parts_Details | 57.2 | 28.6 | 2 |
| df_InTrans_PartsCounter_Raw | 48.2 | 24.1 | 2 |
| df_Fact_Transfers | 47.2 | 23.6 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_GlTrans_Raw | 40.8 | 20.4 | 2 |
| df_Fact_Service_Parts_Detail | 31.2 | 15.6 | 2 |

## Recommendations

- WARNING: Using 71.8% of F4 capacity - monitor closely
- Consider spreading refreshes: 154 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

