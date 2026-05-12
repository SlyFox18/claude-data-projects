# CU Usage Report

**Generated:** 2026-05-12 08:01:39
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1358.4 CU |
| Operations | 124 |
| Avg per Operation | 11 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 59% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 103 | 34.3 | 3 |
| df_Fact_Inventory | 51.2 | 25.6 | 2 |
| df_InTrans_PartsCounter_Raw | 45.8 | 22.9 | 2 |
| df_Fact_InternalWorkOrders | 44.8 | 14.9 | 3 |
| df_Invoice_Raw | 44.5 | 22.2 | 2 |
| df_Fact_Service_Detail | 43.2 | 21.6 | 2 |
| df_Fact_PartSales_24Hours | 40.8 | 13.6 | 3 |
| df_GlTrans_Raw | 38.2 | 19.1 | 2 |
| df_Fact_Service_Invoices | 31.6 | 31.6 | 1 |
| df_InHist_PmManage_Raw | 30.8 | 15.4 | 2 |

## Recommendations

- Consider spreading refreshes: 124 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

