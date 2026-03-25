# CU Usage Report

**Generated:** 2026-03-25 08:01:23
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1317.4 CU |
| Operations | 115 |
| Avg per Operation | 11.5 CU |
| Peak Operation | 37.6 CU |
| F4 Capacity Used | 57.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 93 | 31 | 3 |
| df_Fact_WorkOrderParts | 73.2 | 36.6 | 2 |
| df_Fact_Service_Invoices | 59.2 | 29.6 | 2 |
| df_Fact_Inventory | 55.2 | 27.6 | 2 |
| df_Fact_Parts_Invoices | 43.2 | 21.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_InTrans_PartsCounter_Raw | 39.5 | 19.8 | 2 |
| df_GlTrans_Raw | 34.5 | 17.2 | 2 |
| df_InHist_PmManage_Raw | 32 | 16 | 2 |
| df_Fact_PartSales_24Hours | 29.2 | 14.6 | 2 |

## Recommendations

- Consider spreading refreshes: 115 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

