# CU Usage Report

**Generated:** 2026-04-23 08:01:32
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1411.7 CU |
| Operations | 126 |
| Avg per Operation | 11.2 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 61.3% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 134.2 | 26.8 | 5 |
| df_Fact_Parts_Details | 59.2 | 29.6 | 2 |
| df_Fact_Service_Detail | 49.2 | 24.6 | 2 |
| df_InTrans_PartsCounter_Raw | 47 | 23.5 | 2 |
| df_Fact_PartSales_24Hours | 42.8 | 14.3 | 3 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_GlTrans_Raw | 35.8 | 17.9 | 2 |
| df_Fact_Service_Invoices | 33.6 | 33.6 | 1 |
| df_InHist_PmManage_Raw | 30.8 | 15.4 | 2 |
| df_Fact_Inventory | 29.6 | 29.6 | 1 |

## Recommendations

- WARNING: Using 61.3% of F4 capacity - monitor closely
- Consider spreading refreshes: 126 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

