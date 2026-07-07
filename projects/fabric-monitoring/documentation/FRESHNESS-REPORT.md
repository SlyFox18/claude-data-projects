# Data Freshness Report

**Generated:** 2026-07-07 08:01:31
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 80 | 79.2% |
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
| df_Dim_Customer | 2026-07-07 09:50:24 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-07-07 09:49:22 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-07-07 09:48:52 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-07 09:56:03 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-07 09:54:34 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-07 09:54:33 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-07 09:54:33 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-07 09:55:03 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-07 09:55:03 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-07-07 09:52:53 | -1.9 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-07-07 10:02:02 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-06 14:19:29 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-07 09:58:24 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-07 10:03:54 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-07 10:02:54 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-07 10:02:54 | -2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-07 10:08:07 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-07 10:09:07 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-07 10:08:06 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-07 10:04:27 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-07 10:04:24 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-07 10:09:06 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-07 10:08:36 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-07 10:09:23 | -2.1 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-07 10:13:09 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-07 10:12:08 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-07 10:15:51 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-07 10:15:21 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-07 10:11:39 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-07 10:15:20 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-07 10:15:50 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-07 10:15:53 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-07 10:12:38 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-07 10:13:09 | -2.2 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-07 10:21:37 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-07 10:19:23 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-07 10:21:38 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-07 10:21:38 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-07 10:21:39 | -2.3 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-07 10:21:38 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-07 10:22:37 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-07 12:33:30 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-07-06 14:02:31 | 18 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-07 09:22:15 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-07 09:18:15 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-07 09:21:15 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-07 09:22:15 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-07 09:24:15 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-07 09:23:45 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-07 09:33:30 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-07 09:29:16 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-07 09:32:30 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-07 09:32:59 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-07 09:32:29 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-07 09:31:59 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-07 09:31:59 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-07 09:39:55 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-07 09:39:55 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-07 09:37:12 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-07 09:35:43 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-07 09:39:54 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-07 09:39:55 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-07 09:36:42 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-07 09:39:25 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-07 09:35:42 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-07 09:35:42 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-07 09:39:56 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-07 09:35:42 | -1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-07 09:43:07 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-07 09:43:37 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-07 09:43:08 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-07 09:43:08 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-07 09:43:07 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-07 09:43:07 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-07 09:40:55 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-07-07 09:43:08 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-07 09:42:38 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-07 09:43:07 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-07 12:02:53 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-07 12:05:43 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

