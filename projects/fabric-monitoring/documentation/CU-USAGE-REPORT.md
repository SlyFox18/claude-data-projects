# CU Usage Report

**Generated:** 2026-06-09 08:01:40
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1468.2 CU |
| Operations | 133 |
| Avg per Operation | 11 CU |
| Peak Operation | 69.6 CU |
| F4 Capacity Used | 63.7% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 102 | 25.5 | 4 |
| df_Fact_Service_Invoices | 101.2 | 50.6 | 2 |
| df_InTrans_PartsCounter_Raw | 52 | 26 | 2 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_Invoice_Raw | 43.2 | 21.6 | 2 |
| df_Fact_LaborJobSummary | 37.2 | 18.6 | 2 |
| df_GlTrans_Raw | 37 | 18.5 | 2 |
| df_Fact_First_Pass_Fill | 35.2 | 17.6 | 2 |
| df_InHist_PmManage_Raw | 33.2 | 16.6 | 2 |
| df_Fact_Invoice_UniqueCustomers | 33.2 | 16.6 | 2 |

## Recommendations

- WARNING: Using 63.7% of F4 capacity - monitor closely
- Consider spreading refreshes: 133 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

