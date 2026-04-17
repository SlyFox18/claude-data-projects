# CU Usage Report

**Generated:** 2026-04-17 08:01:51
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1019.1 CU |
| Operations | 88 |
| Avg per Operation | 11.6 CU |
| Peak Operation | 37.2 CU |
| F4 Capacity Used | 44.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 100.8 | 25.2 | 4 |
| df_InTrans_PartsCounter_Raw | 48.2 | 24.1 | 2 |
| df_Invoice_Raw | 40.8 | 20.4 | 2 |
| df_GlTrans_Raw | 35.8 | 17.9 | 2 |
| df_InHist_PmManage_Raw | 32 | 16 | 2 |
| df_Fact_WorkOrderParts | 29.6 | 29.6 | 1 |
| df_Fact_Service_Invoices | 29.6 | 29.6 | 1 |
| df_Fact_PartSales_24Hours | 29.2 | 14.6 | 2 |
| df_Fact_Inventory | 27.6 | 27.6 | 1 |
| df_Fact_Parts_Details | 27.6 | 27.6 | 1 |

## Recommendations

- Consider spreading refreshes: 88 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

