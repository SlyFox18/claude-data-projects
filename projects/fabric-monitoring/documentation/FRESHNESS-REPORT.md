# Data Freshness Report

**Generated:** 2026-09-10 08:01:42
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
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Last refreshed: 2026-08-11 16:05:21 (711.9 hours ago)
- **df_Fact_ServiceRecommendations** (FactTable) - Last refreshed: 2026-08-21 15:56:04 (472.1 hours ago)
- **df_GlMaster_Raw** (RawSource) - Last refreshed: 2026-08-24 13:57:10 (402.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-09-09 10:05:56 | 21.9 | [OK] Fresh |
| df_Dim_Date | 2026-09-10 09:39:52 | -1.6 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-09-10 09:39:52 | -1.6 | [OK] Fresh |
| df_Dim_Salesperson | 2026-09-10 09:45:34 | -1.7 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-09-10 09:45:33 | -1.7 | [OK] Fresh |
| df_Dim_Technicans | 2026-09-10 09:46:03 | -1.7 | [OK] Fresh |
| df_Dim_Customer | 2026-09-10 09:40:22 | -1.7 | [OK] Fresh |
| df_Dim_Part | 2026-09-10 09:43:52 | -1.7 | [OK] Fresh |
| df_Dim_JobCode | 2026-09-10 09:46:05 | -1.7 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-09-10 09:46:33 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-09-10 09:46:33 | -1.8 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 711.9 | [CRIT] Critical |
| df_Fact_ServiceRecommendations | 2026-08-21 15:56:04 | 472.1 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-09-09 14:18:47 | 17.7 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-09-10 09:49:43 | -1.8 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-09-10 09:49:12 | -1.8 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-09-10 09:49:12 | -1.8 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-09-10 09:50:43 | -1.8 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-09-10 09:49:42 | -1.8 | [OK] Fresh |
| df_Fact_Inventory | 2026-09-10 09:49:12 | -1.8 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-09-10 09:55:44 | -1.9 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-09-10 09:55:44 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-09-10 09:53:47 | -1.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-09-10 09:53:18 | -1.9 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-09-10 09:53:48 | -1.9 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-09-10 09:56:14 | -1.9 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-09-10 09:58:10 | -1.9 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-09-10 09:55:45 | -1.9 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-09-10 09:53:18 | -1.9 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-09-10 09:53:17 | -1.9 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-09-10 09:58:10 | -1.9 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-09-10 09:52:49 | -1.9 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-09-10 09:55:44 | -1.9 | [OK] Fresh |
| df_Fact_Transfers | 2026-09-10 09:59:10 | -2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-09-10 09:58:40 | -2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-09-10 10:01:31 | -2 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-09-10 10:03:06 | -2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-09-10 10:01:35 | -2 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-09-10 10:05:06 | -2.1 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-09-10 10:04:37 | -2.1 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-09-10 10:07:05 | -2.1 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-09-10 10:06:08 | -2.1 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-09-10 10:05:07 | -2.1 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-09-10 12:32:21 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_NonJD_Parts_Ordering_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | 2026-08-24 13:57:10 | 402.1 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-09-09 14:02:55 | 18 | [OK] Fresh |
| df_GlTrans_Raw | 2026-09-10 09:22:01 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-09-10 09:19:00 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-09-10 09:20:01 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-09-10 09:22:01 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-09-10 09:18:30 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-09-10 09:17:31 | -1.3 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-09-10 09:24:31 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-09-10 09:26:11 | -1.4 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-09-10 09:27:11 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-09-10 09:26:41 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-09-10 09:26:41 | -1.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-09-10 09:27:11 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-09-10 09:27:11 | -1.4 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-09-10 09:31:35 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-09-10 09:29:09 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-09-10 09:29:39 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-09-10 09:31:36 | -1.5 | [OK] Fresh |
| df_VhTrans_Raw | 2026-09-10 09:31:35 | -1.5 | [OK] Fresh |
| df_CONTACT_Raw | 2026-09-10 09:34:05 | -1.5 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-09-10 09:34:05 | -1.5 | [OK] Fresh |
| df_WarClaim_Raw | 2026-09-10 09:34:06 | -1.5 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-09-10 09:34:35 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-09-10 09:29:38 | -1.5 | [OK] Fresh |
| df_INSALORD_Raw | 2026-09-10 09:29:09 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-09-10 09:28:39 | -1.5 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-09-10 09:29:08 | -1.5 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-09-10 09:32:35 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-09-10 09:31:36 | -1.5 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-09-10 09:31:35 | -1.5 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-09-10 09:31:35 | -1.5 | [OK] Fresh |
| df_Technician_Raw | 2026-09-10 09:34:35 | -1.5 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-09-10 09:34:34 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-09-10 09:34:35 | -1.6 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-09-10 09:34:35 | -1.6 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-09-10 09:34:35 | -1.6 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-09-10 12:52:12 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

