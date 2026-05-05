# CU Usage Report

**Generated:** 2026-05-05 08:01:29
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | -1830.2 CU |
| Operations | 144 |
| Avg per Operation | -12.7 CU |
| Peak Operation | 32.2 CU |
| F4 Capacity Used | -79.4% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 64.5 | 32.2 | 2 |
| df_Fact_Inventory | 53.2 | 26.6 | 2 |
| df_Fact_Service_Detail | 45.2 | 22.6 | 2 |
| df_Fact_PartSales_24Hours | 40.8 | 13.6 | 3 |
| df_Invoice_Raw | 40.8 | 20.4 | 2 |
| df_InTrans_PartsCounter_Raw | 40.8 | 20.4 | 2 |
| df_WKROFILE_Raw | 38 | 12.7 | 3 |
| df_Fact_Parts_Invoices | 35.2 | 17.6 | 2 |
| df_Fact_LaborJobSummary | 35.2 | 17.6 | 2 |
| df_GlTrans_Raw | 32 | 16 | 2 |

## Recommendations

- Consider spreading refreshes: 144 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

