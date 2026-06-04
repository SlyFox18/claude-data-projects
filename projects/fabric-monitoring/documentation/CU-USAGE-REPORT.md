# CU Usage Report

**Generated:** 2026-06-04 08:01:33
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1471.2 CU |
| Operations | 134 |
| Avg per Operation | 11 CU |
| Peak Operation | 37.2 CU |
| F4 Capacity Used | 63.9% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 131.5 | 26.3 | 5 |
| df_Fact_Service_Invoices | 63.2 | 31.6 | 2 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_Fact_Service_Detail | 47.2 | 23.6 | 2 |
| df_InTrans_PartsCounter_Raw | 47 | 23.5 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_Fact_Invoice_UniqueCustomers | 35.2 | 17.6 | 2 |
| df_Fact_LaborJobSummary | 33.2 | 16.6 | 2 |
| df_Fact_First_Pass_Fill | 33.2 | 16.6 | 2 |
| df_InHist_PmManage_Raw | 32 | 16 | 2 |

## Recommendations

- WARNING: Using 63.9% of F4 capacity - monitor closely
- Consider spreading refreshes: 134 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

