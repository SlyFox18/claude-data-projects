# CU Usage Report

**Generated:** 2026-05-22 08:01:36
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1502.8 CU |
| Operations | 132 |
| Avg per Operation | 11.4 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 65.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 139.2 | 23.2 | 6 |
| df_Fact_Service_Invoices | 59.2 | 29.6 | 2 |
| df_Fact_Parts_Details | 55.2 | 27.6 | 2 |
| df_InTrans_PartsCounter_Raw | 50.8 | 25.4 | 2 |
| df_Fact_Transfers | 49.2 | 24.6 | 2 |
| df_Fact_Parts_Invoices | 45.2 | 22.6 | 2 |
| df_Fact_Service_Detail | 43.2 | 21.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_Fact_First_Pass_Fill | 35.2 | 17.6 | 2 |
| df_Fact_LaborJobSummary | 35.2 | 17.6 | 2 |

## Recommendations

- WARNING: Using 65.2% of F4 capacity - monitor closely
- Consider spreading refreshes: 132 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

