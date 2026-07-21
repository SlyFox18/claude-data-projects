# CU Usage Report

**Generated:** 2026-07-21 08:01:36
**Time Period:** Last 24 hours

---

## Summary

| Metric | Value |
|--------|-------|
| Total CU Consumed | 1978.3 CU |
| Operations | 184 |
| Avg per Operation | 10.8 CU |
| Peak Operation | 37.2 CU |
| F4 Capacity Used | 85.9% |

## Top CU Consumers

| Dataflow | Total CU | Avg CU | Runs |
|----------|----------|--------|------|
| df_PartsLookup_Sync | 169.2 | 28.2 | 6 |
| df_JDIS_PART_INFORMATION_Raw | 108 | 36 | 3 |
| df_Fact_Service_Invoices | 61.2 | 30.6 | 2 |
| df_Fact_Parts_Details | 57.2 | 28.6 | 2 |
| df_Fact_WorkOrderParts | 57.2 | 28.6 | 2 |
| df_Fact_Inventory | 49.2 | 24.6 | 2 |
| df_Invoice_Raw | 48 | 16 | 3 |
| df_Fact_Transfers | 45.2 | 22.6 | 2 |
| df_Fact_Service_Detail | 43.2 | 21.6 | 2 |
| df_InMaster_PartsLookup_Raw | 41.2 | 8.2 | 5 |

## Recommendations

- CRITICAL: Using 85.9% of F4 capacity - consider upgrading to F8 or F16
- Consider spreading refreshes: 184 operations at hour 8

---

**Note:** CU estimates are based on refresh duration and category. Actual CU consumption may vary based on query complexity and data volume.

