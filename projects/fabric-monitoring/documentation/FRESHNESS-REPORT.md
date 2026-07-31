# Data Freshness Report

**Generated:** 2026-07-31 08:01:25
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 79 | 77.5% |
| Stale | 2 | 2% |
| Critical | 10 | 9.8% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-07-07 21:47:16 (562.2 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_InMaster_PartsLookup_Raw** (RawSource) - Last refreshed: 2026-07-28 19:14:27 (60.8 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-07-29 10:01:34 (46 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_CommodityCode | 2026-07-07 21:47:16 | 562.2 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-07-29 10:01:34 | 46 | [WARN] Stale |
| df_Dim_Salesperson | 2026-07-31 09:50:58 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-31 09:50:58 | -1.8 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-31 09:51:28 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-31 09:51:28 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-31 09:51:58 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-07-31 09:48:19 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-07-31 09:47:19 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-07-31 09:47:49 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-07-31 09:49:18 | -1.8 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-31 09:50:58 | -1.8 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-30 14:20:07 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-31 09:54:19 | -1.9 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-31 09:55:50 | -1.9 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-31 09:54:50 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-31 09:57:50 | -1.9 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-31 09:56:20 | -1.9 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-31 09:54:50 | -1.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-31 10:00:31 | -2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-31 10:02:02 | -2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-31 10:02:32 | -2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-31 10:00:00 | -2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-31 10:00:30 | -2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-31 10:00:30 | -2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-31 10:05:17 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-31 10:04:47 | -2.1 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-31 10:07:32 | -2.1 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-31 10:04:18 | -2.1 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-31 10:07:33 | -2.1 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-31 10:07:32 | -2.1 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-31 10:07:32 | -2.1 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-31 10:07:31 | -2.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-31 10:04:46 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-31 10:05:19 | -2.1 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-31 10:11:01 | -2.2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-31 10:13:46 | -2.2 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-31 10:13:15 | -2.2 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-31 10:13:14 | -2.2 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-31 10:13:29 | -2.2 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-31 10:12:44 | -2.2 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-31 10:13:14 | -2.2 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-31 12:32:07 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_PartsLookup_Raw | 2026-07-28 19:14:27 | 60.8 | [WARN] Stale |
| df_ServiceTimeSheets_Raw | 2026-07-30 14:02:42 | 18 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-31 09:21:21 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-31 09:17:51 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-31 09:21:51 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-31 09:20:21 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-31 09:22:51 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-31 09:23:51 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-31 09:29:21 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-31 09:32:33 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-31 09:31:33 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-31 09:32:04 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-31 09:32:03 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-31 09:31:33 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-31 09:33:33 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-31 09:37:14 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-31 09:36:14 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-31 09:39:24 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-31 09:39:24 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-31 09:35:44 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-31 09:39:54 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-31 09:39:24 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-31 09:39:54 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-31 09:35:15 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-31 09:39:25 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-31 09:35:45 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-31 09:35:15 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-31 09:39:24 | -1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-31 09:42:06 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-31 09:41:37 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-31 09:42:06 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-31 09:42:06 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-31 09:41:36 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-07-31 09:42:06 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-31 09:42:06 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-31 09:41:36 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-31 09:41:36 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-31 12:02:17 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-31 12:04:48 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

