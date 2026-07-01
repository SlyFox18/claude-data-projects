# CU Usage Report

**Generated:** 2026-07-01 08:01:44
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1801.2 CU |
| Operations | 159 |
| Avg per Operation | 11.3 CU |
| Peak Operation | 37.2 CU |
| F4 Capacity Used | 78.2% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_JDIS_PART_INFORMATION_Raw | 105.5 | 35.2 | 3 |
| df_Fact_Service_Invoices | 67.2 | 33.6 | 2 |
| df_Fact_Parts_Details | 59.2 | 29.6 | 2 |
| df_Fact_Transfers | 57.2 | 28.6 | 2 |
| df_Fact_Inventory | 55.2 | 27.6 | 2 |
| df_Fact_Service_Detail | 47.2 | 23.6 | 2 |
| df_GlTrans_Raw | 45.8 | 22.9 | 2 |
| df_Fact_Parts_Invoices | 45.2 | 22.6 | 2 |
| df_Invoice_Raw | 44.5 | 22.2 | 2 |
| df_Fact_LaborJobSummary | 37.2 | 18.6 | 2 |

## Recommendations

- WARNING: Using 78.2% of F4 capacity - monitor closely
- Consider spreading refreshes: 159 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

