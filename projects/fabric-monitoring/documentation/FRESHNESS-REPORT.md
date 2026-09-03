# Data Freshness Report

**Generated:** 2026-09-03 08:01:43
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 79 | 76% |
| Stale | 0 | 0% |
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
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Last refreshed: 2026-08-11 16:05:21 (543.9 hours ago)
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-17 19:46:00 (396.3 hours ago)
- **df_Fact_ServiceRecommendations** (FactTable) - Last refreshed: 2026-08-21 15:56:04 (304.1 hours ago)
- **df_GlMaster_Raw** (RawSource) - Last refreshed: 2026-08-24 13:57:10 (234.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-09-02 10:01:39 | 22 | [OK] Fresh |
| df_Dim_Date | 2026-09-03 09:44:58 | -1.7 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-09-03 09:45:28 | -1.7 | [OK] Fresh |
| df_Dim_Technicans | 2026-09-03 09:50:17 | -1.8 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-09-03 09:50:47 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-09-03 09:50:16 | -1.8 | [OK] Fresh |
| df_Dim_Salesperson | 2026-09-03 09:50:46 | -1.8 | [OK] Fresh |
| df_Dim_JobCode | 2026-09-03 09:50:46 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-09-03 09:48:07 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-09-03 09:50:46 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-09-03 09:48:31 | -1.8 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 543.9 | [CRIT] Critical |
| df_Fact_ServiceRecommendations | 2026-08-21 15:56:04 | 304.1 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-09-02 14:18:34 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-09-03 09:52:41 | -1.9 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-09-03 09:53:42 | -1.9 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-09-03 09:53:44 | -1.9 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-09-03 09:53:41 | -1.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-09-03 09:56:22 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-09-03 09:54:11 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-09-03 09:56:53 | -1.9 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-09-03 09:57:53 | -1.9 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-09-03 09:56:23 | -1.9 | [OK] Fresh |
| df_Fact_Inventory | 2026-09-03 09:53:14 | -1.9 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-09-03 09:56:52 | -1.9 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-09-03 09:56:24 | -1.9 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-09-03 10:00:05 | -2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-09-03 10:04:24 | -2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-09-03 10:00:35 | -2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-09-03 09:59:35 | -2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-09-03 10:00:05 | -2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-09-03 10:02:05 | -2 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-09-03 10:08:09 | -2.1 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-09-03 10:05:23 | -2.1 | [OK] Fresh |
| df_Fact_Transfers | 2026-09-03 10:06:03 | -2.1 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-09-03 10:08:39 | -2.1 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-09-03 10:08:08 | -2.1 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-09-03 10:04:50 | -2.1 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-09-03 10:08:39 | -2.1 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-09-03 10:08:09 | -2.1 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-09-03 10:05:50 | -2.1 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-09-03 10:06:23 | -2.1 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-09-03 10:09:09 | -2.1 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-09-03 12:33:09 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_Parts_Ordering_Raw | 2026-08-17 19:46:00 | 396.3 | [CRIT] Critical |
| df_GlMaster_Raw | 2026-08-24 13:57:10 | 234.1 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-09-02 14:03:47 | 18 | [OK] Fresh |
| df_GlTrans_Raw | 2026-09-03 09:21:01 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-09-03 09:19:32 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-09-03 09:20:37 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-09-03 09:19:01 | -1.3 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-09-03 09:25:02 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-09-03 09:22:39 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-09-03 09:24:08 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-09-03 09:27:13 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-09-03 09:27:14 | -1.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-09-03 09:27:16 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-09-03 09:27:15 | -1.4 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-09-03 09:34:18 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-09-03 09:32:05 | -1.5 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-09-03 09:34:17 | -1.5 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-09-03 09:34:18 | -1.5 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-09-03 09:34:18 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-09-03 09:28:46 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-09-03 09:32:35 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-09-03 09:32:05 | -1.5 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-09-03 09:32:33 | -1.5 | [OK] Fresh |
| df_INSALORD_Raw | 2026-09-03 09:32:05 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-09-03 09:32:35 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-09-03 09:29:51 | -1.5 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-09-03 09:36:35 | -1.6 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-09-03 09:36:33 | -1.6 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-09-03 09:36:33 | -1.6 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-09-03 09:36:33 | -1.6 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-09-03 09:37:03 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-09-03 09:40:12 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-09-03 09:34:48 | -1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-09-03 09:36:33 | -1.6 | [OK] Fresh |
| df_Technician_Raw | 2026-09-03 09:36:33 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-09-03 09:34:50 | -1.6 | [OK] Fresh |
| df_WarClaim_Raw | 2026-09-03 09:36:33 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-09-03 09:34:50 | -1.6 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-09-03 12:51:58 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

