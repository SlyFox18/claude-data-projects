# CU Usage Report

**Generated:** 2026-05-15 08:01:42
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1447.2 CU |
| Operations | 136 |
| Avg per Operation | 10.6 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 62.8% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 134.2 | 26.8 | 5 |
| df_Fact_Transfers | 62.8 | 20.9 | 3 |
| df_InTrans_PartsCounter_Raw | 47 | 23.5 | 2 |
| df_Fact_Service_Detail | 45.2 | 22.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_Fact_PartSales_24Hours | 38.8 | 12.9 | 3 |
| df_GlTrans_Raw | 33.2 | 16.6 | 2 |
| df_InHist_PmManage_Raw | 32 | 16 | 2 |
| df_Fact_Service_Invoices | 31.6 | 31.6 | 1 |
| df_Fact_CustomerPerformance | 31.2 | 15.6 | 2 |

## Recommendations

- WARNING: Using 62.8% of F4 capacity - monitor closely
- Consider spreading refreshes: 136 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

