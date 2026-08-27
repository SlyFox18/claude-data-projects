# CU Usage Report

**Generated:** 2026-08-27 08:01:39
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1156 CU |
| Operations | 153 |
| Avg per Operation | 7.6 CU |
| Peak Operation | 37.6 CU |
| F4 Capacity Used | 50.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_First_Pass_Fill | 76 | 15.2 | 5 |
| df_JDIS_PART_INFORMATION_Raw | 59.2 | 19.8 | 3 |
| df_Fact_Parts_Invoices | 56.8 | 18.9 | 3 |
| df_InMaster_PartsLookup_Raw | 52.5 | 5.2 | 10 |
| df_GlTrans_Raw | 29.5 | 14.8 | 2 |
| df_Fact_MDInvoices_NoFreight | 28.8 | 9.6 | 3 |
| df_Fact_Invoice_UniqueCustomers | 24.8 | 8.3 | 3 |
| df_Fact_PartSales_24Hours | 24.8 | 8.3 | 3 |
| df_InTrans_PartsCounter_Raw | 23.2 | 11.6 | 2 |
| df_Fact_Service_Parts_Detail | 23.2 | 11.6 | 2 |

## Recommendations

- Consider spreading refreshes: 153 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

