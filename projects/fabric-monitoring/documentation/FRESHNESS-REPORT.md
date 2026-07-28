# Data Freshness Report

**Generated:** 2026-07-28 08:01:31
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 81 | 79.4% |
| Stale | 0 | 0% |
| Critical | 6 | 5.9% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-07-07 21:47:16 (490.2 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_CommodityCode | 2026-07-07 21:47:16 | 490.2 | [CRIT] Critical |
| df_Dim_Part | 2026-07-28 09:49:49 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-28 09:51:31 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-28 09:51:30 | -1.8 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-28 09:51:30 | -1.8 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-28 09:52:02 | -1.8 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-28 09:51:31 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-07-28 09:48:50 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-07-28 09:48:49 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-07-28 09:49:18 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-28 09:52:30 | -1.9 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-07-28 10:02:20 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-27 14:19:34 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-28 09:55:03 | -1.9 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-28 09:56:03 | -1.9 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-28 09:57:03 | -1.9 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-28 09:55:33 | -1.9 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-28 09:57:03 | -1.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-28 10:01:13 | -2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-28 10:02:20 | -2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-28 10:02:43 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-28 09:58:33 | -2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-28 10:01:43 | -2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-28 10:00:43 | -2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-28 10:01:43 | -2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-28 10:04:57 | -2.1 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-28 10:05:39 | -2.1 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-28 10:05:00 | -2.1 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-28 10:07:56 | -2.1 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-28 10:07:55 | -2.1 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-28 10:07:56 | -2.1 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-28 10:07:55 | -2.1 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-28 10:07:56 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-28 10:05:26 | -2.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-28 10:04:56 | -2.1 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-28 10:15:15 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-28 10:11:59 | -2.2 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-28 10:14:15 | -2.2 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-28 10:13:49 | -2.2 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-28 10:13:45 | -2.2 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-28 10:14:15 | -2.2 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-28 10:13:45 | -2.2 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-28 12:32:13 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-07-27 14:03:22 | 18 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-28 09:21:43 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-28 09:17:43 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-28 09:22:14 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-28 09:20:43 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-28 09:23:13 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-28 09:23:44 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-28 09:29:13 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-28 09:32:05 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-28 09:31:35 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-28 09:32:35 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-28 09:32:05 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-28 09:31:35 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-28 09:33:09 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-28 09:36:23 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-28 09:37:09 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-28 09:39:21 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-28 09:39:21 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-28 09:39:51 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-28 09:39:21 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-28 09:39:21 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-28 09:35:39 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-28 09:39:21 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-28 09:39:21 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-28 09:35:23 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-28 09:35:23 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-28 09:34:53 | -1.6 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-28 09:41:35 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-28 09:42:05 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-28 09:42:05 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-28 09:42:05 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-28 09:42:05 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-28 09:42:05 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-07-28 09:42:05 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-28 09:41:35 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-28 09:41:44 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-28 12:03:03 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-28 12:05:03 | -4.1 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-07-28 12:51:35 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

