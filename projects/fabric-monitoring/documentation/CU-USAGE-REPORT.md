# CU Usage Report

**Generated:** 2026-08-10 08:01:41
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | -1359.6 CU |
| Operations | 99 |
| Avg per Operation | -13.7 CU |
| Peak Operation | 63.6 CU |
| F4 Capacity Used | -59% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_Fact_WorkOrderParts | 87.2 | 43.6 | 2 |
| df_Fact_Parts_Details | 43.2 | 21.6 | 2 |
| df_JDIS_PART_INFORMATION_Raw | 41 | 41 | 1 |
| df_Fact_First_Pass_Fill | 33.2 | 16.6 | 2 |
| df_Fact_Service_Parts_Detail | 33.2 | 16.6 | 2 |
| df_Fact_Service_Detail | 29.2 | 14.6 | 2 |
| df_Fact_Parts_Invoices | 27.2 | 13.6 | 2 |
| df_Fact_Service_Invoices | 23.2 | 11.6 | 2 |
| df_Fact_Invoice_UniqueCustomers | 23.2 | 11.6 | 2 |
| df_Invoice_Raw | 22.2 | 22.2 | 1 |

## Recommendations

- Consider spreading refreshes: 99 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

