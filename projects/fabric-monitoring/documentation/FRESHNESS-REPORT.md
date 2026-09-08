# Data Freshness Report

**Generated:** 2026-09-08 08:01:41
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

- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Last refreshed: 2026-08-11 16:05:21 (663.9 hours ago)
- **df_Fact_ServiceRecommendations** (FactTable) - Last refreshed: 2026-08-21 15:56:04 (424.1 hours ago)
- **df_GlMaster_Raw** (RawSource) - Last refreshed: 2026-08-24 13:57:10 (354.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Part | 2026-09-08 09:44:38 | -1.7 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-09-08 09:46:05 | -1.7 | [OK] Fresh |
| df_Dim_Salesperson | 2026-09-08 09:46:05 | -1.7 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-09-08 09:40:23 | -1.7 | [OK] Fresh |
| df_Dim_Date | 2026-09-08 09:40:53 | -1.7 | [OK] Fresh |
| df_Dim_Customer | 2026-09-08 09:40:53 | -1.7 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-09-08 09:46:34 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-09-08 09:46:35 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-09-08 09:47:05 | -1.8 | [OK] Fresh |
| df_Dim_JobCode | 2026-09-08 09:46:34 | -1.8 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-09-08 10:03:19 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 663.9 | [CRIT] Critical |
| df_Fact_ServiceRecommendations | 2026-08-21 15:56:04 | 424.1 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-09-07 14:18:12 | 17.7 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-09-08 09:49:45 | -1.8 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-09-08 09:49:43 | -1.8 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-09-08 09:49:44 | -1.8 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-09-08 09:50:44 | -1.8 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-09-08 09:49:44 | -1.8 | [OK] Fresh |
| df_Fact_Inventory | 2026-09-08 09:49:43 | -1.8 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-09-08 09:55:44 | -1.9 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-09-08 09:56:14 | -1.9 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-09-08 09:55:45 | -1.9 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-09-08 09:55:43 | -1.9 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-09-08 09:53:49 | -1.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-09-08 09:52:48 | -1.9 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-09-08 09:58:11 | -1.9 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-09-08 09:52:48 | -1.9 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-09-08 09:58:10 | -1.9 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-09-08 09:57:41 | -1.9 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-09-08 09:53:18 | -1.9 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-09-08 09:53:18 | -1.9 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-09-08 09:58:10 | -1.9 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-09-08 09:55:44 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-09-08 09:53:48 | -1.9 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-09-08 10:02:38 | -2 | [OK] Fresh |
| df_Fact_Transfers | 2026-09-08 09:59:11 | -2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-09-08 10:02:37 | -2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-09-08 09:59:41 | -2 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-09-08 10:02:07 | -2 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-09-08 10:02:38 | -2 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-09-08 10:03:39 | -2 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-09-08 10:01:38 | -2 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-09-08 12:32:25 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_NonJD_Parts_Ordering_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | 2026-08-24 13:57:10 | 354.1 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-09-07 14:03:21 | 18 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-09-08 09:19:41 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-09-08 09:19:11 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-09-08 09:19:41 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-09-08 09:18:11 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-09-08 09:21:11 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-09-08 09:18:41 | -1.3 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-09-08 09:24:54 | -1.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-09-08 09:24:54 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-09-08 09:24:53 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-09-08 09:24:23 | -1.4 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-09-08 09:26:52 | -1.4 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-09-08 09:27:21 | -1.4 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-09-08 09:26:21 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-09-08 09:24:53 | -1.4 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-09-08 09:27:22 | -1.4 | [OK] Fresh |
| df_INSALORD_Raw | 2026-09-08 09:26:21 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-09-08 09:24:53 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-09-08 09:22:41 | -1.4 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-09-08 09:26:51 | -1.4 | [OK] Fresh |
| df_WarClaim_Raw | 2026-09-08 09:31:49 | -1.5 | [OK] Fresh |
| df_VhTrans_Raw | 2026-09-08 09:28:50 | -1.5 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-09-08 09:30:48 | -1.5 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-09-08 09:31:18 | -1.5 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-09-08 09:31:19 | -1.5 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-09-08 09:30:48 | -1.5 | [OK] Fresh |
| df_CONTACT_Raw | 2026-09-08 09:31:20 | -1.5 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-09-08 09:30:50 | -1.5 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-09-08 09:28:50 | -1.5 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-09-08 09:29:21 | -1.5 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-09-08 09:29:20 | -1.5 | [OK] Fresh |
| df_Technician_Raw | 2026-09-08 09:31:19 | -1.5 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-09-08 09:30:49 | -1.5 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-09-08 09:29:20 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-09-08 09:29:20 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-09-08 09:29:20 | -1.5 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-09-08 12:52:11 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

