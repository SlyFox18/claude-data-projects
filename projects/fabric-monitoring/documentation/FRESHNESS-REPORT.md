# Data Freshness Report

**Generated:** 2026-03-23 12:09:06
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 66 | 63.5% |
| Stale | 0 | 0% |
| Critical | 25 | 24% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_Machines_Serviced** (FactTable) - Never refreshed!
- **df_Fact_Part_Transactions** (FactTable) - Never refreshed!
- **df_Fact_PartTransactions** (FactTable) - Never refreshed!
- **df_Fact_LaborJobs** (FactTable) - Never refreshed!
- **df_Fact_LaborPunches** (FactTable) - Never refreshed!
- **df_Fact_LaborWIP** (FactTable) - Never refreshed!
- **df_Fact_WorkOrderJobs** (FactTable) - Never refreshed!
- **df_Fact_WorkOrderLabor** (FactTable) - Never refreshed!
- **df_INTRANS_Raw** (RawSource) - Never refreshed!
- **df_Fact_WarrantyClaims** (FactTable) - Never refreshed!
- **df_Fact_WorkOrderComprehensive** (FactTable) - Never refreshed!
- **df_Fact_WorkOrderHeader** (FactTable) - Never refreshed!
- **df_Fact_LaborInvoiced** (FactTable) - Never refreshed!
- **df_Dim_InvoiceLookup** (Dimension) - Never refreshed!
- **df_Dim_InvoiceType** (Dimension) - Never refreshed!
- **df_Dim_SlicerControl** (Dimension) - Never refreshed!
- **df_CustomerAnatomy_Raw** (RawSource) - Never refreshed!
- **df_Dim_Branch** (Dimension) - Never refreshed!
- **df_Dim_BranchFranchise** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderStatus** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderType** (Dimension) - Never refreshed!
- **df_Fact_InvoiceHeader** (FactTable) - Never refreshed!
- **df_Dim_Vehicle** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderLookup** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderMaster** (Dimension) - Never refreshed!

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_Vehicle | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_SlicerControl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderType | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderStatus | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderMaster | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderLookup | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_InvoiceType | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_InvoiceLookup | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchFranchise | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Customer | 2026-03-23 09:51:43 | 2.3 | [OK] Fresh |
| df_Dim_Date | 2026-03-23 09:51:15 | 2.3 | [OK] Fresh |
| df_Dim_Part | 2026-03-23 09:54:13 | 2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-03-23 09:56:53 | 2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-03-23 09:56:53 | 2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-03-23 09:56:23 | 2.2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-03-23 09:56:23 | 2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-03-23 15:58:44 | -3.8 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_LaborInvoiced | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_InvoiceHeader | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Part_Transactions | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborJobs | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Machines_Serviced | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborWIP | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborPunches | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderComprehensive | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderLabor | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderJobs | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderHeader | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PartTransactions | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WarrantyClaims | Never | 999999 | [NEVER] Never Refreshed |
| df_FactPartTransactions_Incremental | 2026-03-23 09:59:49 | 2.2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-03-23 10:03:48 | 2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-03-23 10:05:17 | 2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-03-23 10:04:49 | 2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-03-23 10:04:51 | 2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-03-23 10:11:38 | 2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-03-23 10:07:50 | 2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-03-23 10:15:59 | 1.9 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-03-23 10:16:23 | 1.9 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-03-23 10:12:39 | 1.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-03-23 10:12:07 | 1.9 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-03-23 10:12:14 | 1.9 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-03-23 10:15:56 | 1.9 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-03-23 10:15:53 | 1.9 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-03-23 10:12:39 | 1.9 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-03-23 10:13:10 | 1.9 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-03-23 10:19:36 | 1.8 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-03-23 10:19:37 | 1.8 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-03-23 10:19:37 | 1.8 | [OK] Fresh |
| df_Fact_Transfers | 2026-03-23 10:23:10 | 1.8 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-03-23 10:25:24 | 1.7 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-03-23 10:25:25 | 1.7 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-03-23 10:25:25 | 1.7 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-03-23 10:26:25 | 1.7 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-03-23 16:18:33 | -4.2 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_INTRANS_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_CustomerAnatomy_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_Parts_InterbranchTransfer_Raw | 2026-03-23 09:17:45 | 2.9 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-03-23 09:21:15 | 2.8 | [OK] Fresh |
| df_GlTrans_Raw | 2026-03-23 09:21:45 | 2.8 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-03-23 09:23:15 | 2.8 | [OK] Fresh |
| df_Invoice_Raw | 2026-03-23 09:23:15 | 2.8 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-03-23 09:20:15 | 2.8 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-03-23 09:30:29 | 2.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-03-23 09:34:09 | 2.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-03-23 09:34:08 | 2.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-03-23 09:35:08 | 2.6 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-03-23 09:30:28 | 2.6 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-03-23 09:31:28 | 2.6 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-03-23 09:30:58 | 2.6 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-03-23 09:30:58 | 2.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-03-23 09:34:38 | 2.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-03-23 09:34:07 | 2.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-03-23 09:40:51 | 2.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-03-23 09:41:50 | 2.5 | [OK] Fresh |
| df_VhTrans_Raw | 2026-03-23 09:40:20 | 2.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-03-23 09:37:39 | 2.5 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-03-23 09:39:50 | 2.5 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-03-23 09:40:21 | 2.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-03-23 09:40:21 | 2.5 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-03-23 09:44:33 | 2.4 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-03-23 09:44:33 | 2.4 | [OK] Fresh |
| df_WarClaim_Raw | 2026-03-23 09:44:33 | 2.4 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-03-23 09:44:33 | 2.4 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-03-23 09:44:33 | 2.4 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-03-23 09:45:03 | 2.4 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-03-23 09:44:33 | 2.4 | [OK] Fresh |
| df_Technician_Raw | 2026-03-23 09:44:33 | 2.4 | [OK] Fresh |
| df_CONTACT_Raw | 2026-03-23 09:44:33 | 2.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-03-23 16:14:20 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

