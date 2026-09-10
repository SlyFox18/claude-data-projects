# CU Usage Report

**Generated:** 2026-09-10 08:01:48
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1203 CU |
| Operations | 177 |
| Avg per Operation | 6.8 CU |
| Peak Operation | 22.8 CU |
| F4 Capacity Used | 52.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 58.2 | 19.4 | 3 |
| df_InMaster_PartsLookup_Raw | 57.8 | 5.2 | 11 |
| df_Fact_Planter_Inspection_Part_Sales | 34.8 | 17.4 | 2 |
| df_WKROFILE_Raw | 32.2 | 8.1 | 4 |
| df_GlTrans_Raw | 31.8 | 15.9 | 2 |
| df_InTrans_PartsCounter_Raw | 26.8 | 13.4 | 2 |
| df_Fact_Parts_Details | 24.8 | 12.4 | 2 |
| df_Fact_PartSales_24Hours | 23.2 | 7.7 | 3 |
| df_Invoice_Raw | 23 | 11.5 | 2 |
| df_Fact_MDInvoices_Closed | 21.2 | 7.1 | 3 |

## Recommendations

- Consider spreading refreshes: 177 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

