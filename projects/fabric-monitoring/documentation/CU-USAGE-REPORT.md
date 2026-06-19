# CU Usage Report

**Generated:** 2026-06-19 08:01:37
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1647 CU |
| Operations | 134 |
| Avg per Operation | 12.3 CU |
| Peak Operation | 61.6 CU |
| F4 Capacity Used | 71.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_ServiceTimeSheet_Audit | 214.8 | 17.9 | 12 |
| df_JDIS_PART_INFORMATION_Raw | 132.8 | 33.2 | 4 |
| df_Fact_Service_Parts_Detail | 92.8 | 30.9 | 3 |
| df_Fact_Invoice_UniqueCustomers | 77.2 | 19.3 | 4 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_LaborJobSummary | 58.8 | 19.6 | 3 |
| df_Fact_Parts_Details | 55.2 | 27.6 | 2 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_InTrans_PartsCounter_Raw | 45.8 | 22.9 | 2 |
| df_Fact_Service_Detail | 43.2 | 21.6 | 2 |

## Recommendations

- WARNING: Using 71.5% of F4 capacity - monitor closely
- Consider spreading refreshes: 134 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

