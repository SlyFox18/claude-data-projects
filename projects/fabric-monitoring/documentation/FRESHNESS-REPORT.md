# Data Freshness Report

**Generated:** 2026-07-09 08:01:35
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 81 | 80.2% |
| Stale | 0 | 0% |
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

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_CommodityCode | 2026-07-07 21:47:16 | 34.2 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-07-08 10:01:35 | 22 | [OK] Fresh |
| df_Dim_Date | 2026-07-09 09:58:12 | -1.9 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-07-09 09:57:41 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-09 10:03:04 | -2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-09 10:03:31 | -2 | [OK] Fresh |
| df_Dim_Part | 2026-07-09 10:01:11 | -2 | [OK] Fresh |
| df_Dim_Customer | 2026-07-09 09:59:11 | -2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-09 10:03:30 | -2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-09 10:03:03 | -2 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-09 10:04:33 | -2.1 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-09 10:04:32 | -2.1 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-08 14:18:28 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-09 10:07:02 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-09 10:11:31 | -2.2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-09 10:10:59 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-09 10:12:29 | -2.2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-09 10:13:02 | -2.2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-09 10:12:31 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-09 10:18:14 | -2.3 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-09 10:16:44 | -2.3 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-09 10:20:29 | -2.3 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-09 10:16:45 | -2.3 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-09 10:20:27 | -2.3 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-09 10:21:58 | -2.3 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-09 10:17:44 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-09 10:17:45 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-09 10:21:27 | -2.3 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-09 10:17:44 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-09 10:24:38 | -2.4 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-09 10:25:09 | -2.4 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-09 10:22:27 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-09 10:24:39 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-09 10:24:39 | -2.4 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-09 10:24:39 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-09 10:30:52 | -2.5 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-09 10:32:22 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-09 10:28:40 | -2.5 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-09 10:30:53 | -2.5 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-09 10:30:53 | -2.5 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-09 10:30:53 | -2.5 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-09 10:30:53 | -2.5 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-09 12:33:30 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-07-08 14:02:38 | 18 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-09 09:18:14 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-09 09:22:14 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-09 09:20:44 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-09 09:22:44 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-09 09:24:14 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-09 09:25:44 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-09 09:39:36 | -1.6 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-09 09:35:22 | -1.6 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-09 09:39:01 | -1.6 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-09 09:37:36 | -1.6 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-09 09:38:07 | -1.6 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-09 09:38:07 | -1.6 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-09 09:37:36 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-09 09:41:51 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-09 09:43:50 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-09 09:46:03 | -1.7 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-09 09:43:20 | -1.7 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-09 09:41:50 | -1.7 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-09 09:41:20 | -1.7 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-09 09:41:51 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-09 09:46:33 | -1.8 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-09 09:49:48 | -1.8 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-09 09:52:26 | -1.8 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-09 09:49:48 | -1.8 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-09 09:49:48 | -1.8 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-09 09:49:48 | -1.8 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-09 09:49:48 | -1.8 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-09 09:49:48 | -1.8 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-09 09:46:33 | -1.8 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-09 09:46:33 | -1.8 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-09 09:46:32 | -1.8 | [OK] Fresh |
| df_Technician_Raw | 2026-07-09 09:49:48 | -1.8 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-09 09:49:48 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-09 09:47:33 | -1.8 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-09 09:46:33 | -1.8 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-09 12:02:14 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-09 12:05:15 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

