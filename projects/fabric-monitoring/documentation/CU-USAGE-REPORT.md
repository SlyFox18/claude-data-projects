# CU Usage Report

**Generated:** 2026-05-27 08:02:29
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1440.2 CU |
| Operations | 136 |
| Avg per Operation | 10.6 CU |
| Peak Operation | 33.6 CU |
| F4 Capacity Used | 62.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 91.8 | 30.6 | 3 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_Parts_Details | 53.2 | 26.6 | 2 |
| df_Fact_Transfers | 49.2 | 24.6 | 2 |
| df_Invoice_Raw | 44.5 | 22.2 | 2 |
| df_InTrans_PartsCounter_Raw | 43.2 | 21.6 | 2 |
| df_Fact_First_Pass_Fill | 42.8 | 14.3 | 3 |
| df_Fact_Service_Detail | 41.2 | 20.6 | 2 |
| df_GlTrans_Raw | 37 | 18.5 | 2 |
| df_Fact_LaborJobSummary | 35.2 | 17.6 | 2 |

## Recommendations

- WARNING: Using 62.5% of F4 capacity - monitor closely
- Consider spreading refreshes: 136 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

