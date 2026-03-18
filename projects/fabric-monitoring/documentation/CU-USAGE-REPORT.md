# CU Usage Report

**Generated:** 2026-03-18 06:01:39
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1176.1 CU |
| Operations | 93 |
| Avg per Operation | 12.6 CU |
| Peak Operation | 65.6 CU |
| F4 Capacity Used | 51% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 129.5 | 18.5 | 7 |
| df_Fact_Parts_Details | 71.2 | 35.6 | 2 |
| df_FactPartTransactions_Incremental | 65.6 | 65.6 | 1 |
| df_Fact_Parts_Invoices | 61.6 | 20.5 | 3 |
| df_Fact_WorkOrderParts | 59.6 | 59.6 | 1 |
| df_Fact_Service_Invoices | 53.6 | 53.6 | 1 |
| df_GlTrans_Raw | 51 | 8.5 | 6 |
| df_Fact_PartSales_24Hours | 50.8 | 16.9 | 3 |
| df_Invoice_Raw | 50 | 10 | 5 |
| df_InHist_PmManage_Raw | 45 | 9 | 5 |

## Recommendations

- Consider spreading refreshes: 42 operations at hour 9

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

