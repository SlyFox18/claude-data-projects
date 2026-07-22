# Data Freshness Report

**Generated:** 2026-07-22 08:01:32
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 81 | 79.4% |
| Stale | 0 | 0% |
| Critical | 5 | 4.9% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-07-07 21:47:16 (346.2 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_CommodityCode | 2026-07-07 21:47:16 | 346.2 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-07-22 10:02:00 | -2 | [OK] Fresh |
| df_Dim_Part | 2026-07-22 10:14:15 | -2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-22 10:15:56 | -2.2 | [OK] Fresh |
| df_Dim_Date | 2026-07-22 10:11:13 | -2.2 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-07-22 10:11:14 | -2.2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-22 10:15:56 | -2.2 | [OK] Fresh |
| df_Dim_Customer | 2026-07-22 10:12:14 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-22 10:16:28 | -2.3 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-22 10:16:27 | -2.3 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-22 10:16:26 | -2.3 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-22 10:17:26 | -2.3 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-21 14:19:36 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-22 10:19:52 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-22 10:24:22 | -2.4 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-22 10:23:23 | -2.4 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-22 10:24:23 | -2.4 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-22 10:25:22 | -2.4 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-22 10:24:53 | -2.4 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-22 10:32:21 | -2.5 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-22 10:30:02 | -2.5 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-22 10:29:02 | -2.5 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-22 10:32:19 | -2.5 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-22 10:29:02 | -2.5 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-22 10:32:49 | -2.5 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-22 10:33:47 | -2.5 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-22 10:29:32 | -2.5 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-22 10:29:32 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-22 10:29:32 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-22 10:33:19 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-22 10:39:32 | -2.6 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-22 10:36:01 | -2.6 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-22 10:36:01 | -2.6 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-22 10:36:01 | -2.6 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-22 10:36:31 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-22 10:42:50 | -2.7 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-22 10:45:20 | -2.7 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-22 10:42:50 | -2.7 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-22 10:42:50 | -2.7 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-22 10:42:50 | -2.7 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-22 10:42:49 | -2.7 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-22 10:40:37 | -2.7 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-22 12:33:06 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_PartsLookup_Raw | 2026-07-21 12:48:51 | 19.2 | [OK] Fresh |
| df_ServiceTimeSheets_Raw | 2026-07-21 14:02:39 | 18 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-22 09:22:23 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-22 09:18:22 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-22 09:20:53 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-22 09:23:52 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-22 09:24:22 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-22 09:23:23 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-22 09:30:23 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-22 09:33:05 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-22 09:33:05 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-22 09:32:35 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-22 09:33:35 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-22 09:32:35 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-22 09:36:48 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-22 09:34:35 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-22 09:38:48 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-22 09:36:48 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-22 09:36:48 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-22 09:36:48 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-22 09:45:33 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-22 09:42:36 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-22 09:45:33 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-22 09:45:33 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-22 09:45:01 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-22 09:45:32 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-22 09:48:15 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-22 10:02:41 | -2 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-22 10:04:58 | -2.1 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-22 10:05:08 | -2.1 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-22 10:05:00 | -2.1 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-22 10:05:03 | -2.1 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-22 10:04:58 | -2.1 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-22 10:05:02 | -2.1 | [OK] Fresh |
| df_Technician_Raw | 2026-07-22 10:04:59 | -2.1 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-22 10:04:31 | -2.1 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-22 10:05:00 | -2.1 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-22 12:02:15 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-22 12:05:20 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

