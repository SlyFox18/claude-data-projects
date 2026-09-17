# CU Usage Report

**Generated:** 2026-09-17 08:01:39
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 900.2 CU |
| Operations | 144 |
| Avg per Operation | 6.3 CU |
| Peak Operation | 22.8 CU |
| F4 Capacity Used | 39.1% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 58.2 | 19.4 | 3 |
| df_InMaster_PartsLookup_Raw | 57.8 | 5.2 | 11 |
| df_GlTrans_Raw | 29.2 | 14.6 | 2 |
| df_Fact_PartSales_24Hours | 25.2 | 8.4 | 3 |
| df_InTrans_PartsCounter_Raw | 23 | 11.5 | 2 |
| df_Invoice_Raw | 20.5 | 10.2 | 2 |
| df_InHist_PmManage_Raw | 19.2 | 9.6 | 2 |
| df_Fact_Service_Detail | 18.8 | 9.4 | 2 |
| df_Fact_Service_Invoices | 16.8 | 8.4 | 2 |
| df_Fact_Invoice_InventoryAnalysis | 16.8 | 8.4 | 2 |

## Recommendations

- Consider spreading refreshes: 144 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

