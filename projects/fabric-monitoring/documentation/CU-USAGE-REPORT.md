# CU Usage Report

**Generated:** 2026-03-26 08:01:38
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | -4331.4 CU |
| Operations | 124 |
| Avg per Operation | -34.9 CU |
| Peak Operation | 111.6 CU |
| F4 Capacity Used | -188% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 126.5 | 31.6 | 4 |
| df_Fact_Transfers | 106.8 | 26.7 | 4 |
| df_Fact_Parts_Invoices | 43.2 | 21.6 | 2 |
| df_Invoice_Raw | 42 | 21 | 2 |
| df_Fact_First_Pass_Fill | 37.2 | 18.6 | 2 |
| df_GlTrans_Raw | 37 | 18.5 | 2 |
| df_Dim_Part | 33.9 | 17 | 2 |
| df_Fact_PartSales_24Hours | 31.2 | 15.6 | 2 |
| df_InHist_PmManage_Raw | 30.8 | 15.4 | 2 |
| df_Fact_Service_Parts_Detail | 27.2 | 13.6 | 2 |

## Recommendations

- Consider spreading refreshes: 124 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

