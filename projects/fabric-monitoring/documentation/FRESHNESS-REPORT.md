# Data Freshness Report

**Generated:** 2026-07-10 08:01:36
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 79 | 78.2% |
| Stale | 2 | 2% |
| Critical | 4 | 4% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-07-07 21:47:16 (58.2 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-07-08 10:01:35 (46 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_CommodityCode | 2026-07-07 21:47:16 | 58.2 | [WARN] Stale |
| df_Dim_BranchUserAccess | 2026-07-08 10:01:35 | 46 | [WARN] Stale |
| df_Dim_Date | 2026-07-10 09:50:08 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-07-10 09:51:08 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-07-10 09:49:37 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-10 09:55:18 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-10 09:55:19 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-10 09:55:19 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-10 09:56:18 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-10 09:55:19 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-10 09:55:19 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-07-10 09:53:08 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-09 14:19:28 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-10 09:58:39 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-10 10:03:10 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-10 10:04:10 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-10 10:02:39 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-10 10:04:09 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-10 10:05:10 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-10 10:09:18 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-10 10:10:23 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-10 10:09:57 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-10 10:09:15 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-10 10:09:52 | -2.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-10 10:13:16 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-10 10:10:41 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-10 10:14:46 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-10 10:13:18 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-10 10:14:15 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-10 10:13:46 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-10 10:16:59 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-10 10:21:30 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-10 10:17:03 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-10 10:17:39 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-10 10:16:59 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-10 10:16:59 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-10 10:23:45 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-10 10:24:47 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-10 10:23:46 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-10 10:23:46 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-10 10:23:44 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-10 10:23:46 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-10 12:33:28 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-07-09 14:02:33 | 18 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-10 09:22:15 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-10 09:18:15 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-10 09:20:45 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-10 09:21:45 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-10 09:24:16 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-10 09:24:15 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-10 09:33:58 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-10 09:29:46 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-10 09:32:28 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-10 09:32:27 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-10 09:32:28 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-10 09:32:58 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-10 09:32:27 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-10 09:40:24 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-10 09:40:25 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-10 09:37:40 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-10 09:36:10 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-10 09:40:24 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-10 09:40:25 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-10 09:37:08 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-10 09:39:54 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-10 09:36:08 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-10 09:36:08 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-10 09:39:54 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-10 09:36:08 | -1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-10 09:44:08 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-10 09:44:09 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-10 09:44:08 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-10 09:44:10 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-10 09:44:10 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-10 09:44:09 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-10 09:41:54 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-07-10 09:44:09 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-10 09:43:39 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-10 09:44:14 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-10 12:02:44 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-10 12:05:06 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

