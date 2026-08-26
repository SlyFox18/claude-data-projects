# Data Freshness Report

**Generated:** 2026-08-26 08:01:37
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 73 | 70.2% |
| Stale |  | 0% |
| Critical | 12 | 11.5% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:05:30 (523.9 hours ago)
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Last refreshed: 2026-08-11 16:05:21 (351.9 hours ago)
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-17 19:46:00 (204.3 hours ago)
- **df_Fact_ServiceRecommendations** (FactTable) - Last refreshed: 2026-08-21 15:56:04 (112.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Date | 2026-08-26 09:39:55 | -1.6 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-26 09:39:55 | -1.6 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-26 09:44:04 | -1.7 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-26 09:44:36 | -1.7 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-26 09:44:34 | -1.7 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-26 09:44:34 | -1.7 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-26 09:44:35 | -1.7 | [OK] Fresh |
| df_Dim_Customer | 2026-08-26 09:40:24 | -1.7 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-08-26 09:45:04 | -1.7 | [OK] Fresh |
| df_Dim_Part | 2026-08-26 09:42:54 | -1.7 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-08-26 10:02:17 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 351.9 | [CRIT] Critical |
| df_Fact_ServiceRecommendations | 2026-08-21 15:56:04 | 112.1 | [CRIT] Critical |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-25 14:20:46 | 17.7 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-25 14:20:46 | 17.7 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-08-25 14:21:45 | 17.7 | [OK] Fresh |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-25 14:19:36 | 17.7 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-08-25 14:20:45 | 17.7 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-08-25 14:20:46 | 17.7 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-08-25 14:20:45 | 17.7 | [OK] Fresh |
| df_Fact_Equipment_Sales | Error | 0 | [?] Error |
| df_Fact_Transfers | Error | 0 | [?] Error |
| df_Fact_InTrans_UniqueCustomers | Error | 0 | [?] Error |
| df_Fact_PendingInspections | Error | 0 | [?] Error |
| df_Fact_MDInvoices_Closed | Error | 0 | [?] Error |
| df_Fact_MDInvoices_NoFreight | Error | 0 | [?] Error |
| df_Fact_InternalWorkOrders | 2026-08-26 12:32:10 | -4.5 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-26 12:57:35 | -4.9 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-08-26 12:53:42 | -4.9 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-26 12:57:04 | -4.9 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-08-26 12:54:12 | -4.9 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-26 12:54:12 | -4.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-26 12:57:04 | -4.9 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-26 12:54:12 | -4.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-26 12:54:42 | -4.9 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-26 12:57:36 | -4.9 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-26 12:57:04 | -4.9 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-26 12:53:42 | -4.9 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-26 12:57:04 | -4.9 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-26 12:59:46 | -5 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-26 12:59:46 | -5 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-26 12:59:45 | -5 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-26 12:59:46 | -5 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-26 12:59:46 | -5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 523.9 | [CRIT] Critical |
| df_InMaster_Parts_Ordering_Raw | 2026-08-17 19:46:00 | 204.3 | [CRIT] Critical |
| df_GlMaster_Raw | 2026-08-24 13:57:10 | 42.1 | [WARN] Stale |
| df_ServiceTimeSheets_Raw | 2026-08-25 14:10:11 | 17.9 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-26 09:17:24 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-08-26 09:18:53 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-26 09:19:24 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-26 09:19:24 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-26 09:18:23 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-26 09:20:54 | -1.3 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-26 09:25:05 | -1.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-26 09:25:36 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-26 09:25:36 | -1.4 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-26 09:26:07 | -1.4 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-26 09:27:47 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-26 09:25:37 | -1.4 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-26 09:28:20 | -1.4 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-26 09:28:17 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-26 09:26:06 | -1.4 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-26 09:27:47 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-26 09:23:24 | -1.4 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-26 09:34:14 | -1.5 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-26 09:34:15 | -1.5 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-26 09:32:02 | -1.5 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-26 09:32:02 | -1.5 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-26 09:34:14 | -1.5 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-26 09:34:15 | -1.5 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-26 09:34:14 | -1.5 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-26 09:34:14 | -1.5 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-26 09:34:14 | -1.5 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-26 09:32:01 | -1.5 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-26 09:29:27 | -1.5 | [OK] Fresh |
| df_Technician_Raw | 2026-08-26 09:34:16 | -1.5 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-26 09:32:02 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-26 09:32:32 | -1.5 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-26 09:32:33 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-26 09:32:01 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-26 09:30:18 | -1.5 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-26 09:34:44 | -1.6 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-08-26 12:51:57 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

