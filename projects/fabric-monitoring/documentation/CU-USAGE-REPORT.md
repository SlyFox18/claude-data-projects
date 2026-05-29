# CU Usage Report

**Generated:** 2026-05-29 08:01:30
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1554 CU |
| Operations | 143 |
| Avg per Operation | 10.9 CU |
| Peak Operation | 38.5 CU |
| F4 Capacity Used | 67.5% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 129.5 | 21.6 | 6 |
| df_Fact_ServiceTimeSheet_Audit | 128.4 | 14.3 | 9 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_Inventory | 58.8 | 19.6 | 3 |
| df_Fact_Parts_Details | 55.2 | 27.6 | 2 |
| df_InTrans_PartsCounter_Raw | 48.2 | 24.1 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_InHist_PmManage_Raw | 39.2 | 13.1 | 3 |
| df_Fact_PartSales_24Hours | 36.8 | 12.3 | 3 |
| df_GlTrans_Raw | 33.2 | 16.6 | 2 |

## Recommendations

- WARNING: Using 67.5% of F4 capacity - monitor closely
- Consider spreading refreshes: 143 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

