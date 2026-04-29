# Data Freshness Report

**Generated:** 2026-04-29 08:01:34
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 73 | 83% |
| Stale | 0 | 0% |
| Critical | 2 | 2.3% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (318.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-23 19:54:02 (132.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 132.1 | [CRIT] Critical |
| df_Dim_Part | 2026-04-29 09:51:31 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-04-29 09:49:01 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-04-29 09:48:32 | -1.8 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-29 09:57:18 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-29 09:57:20 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-29 09:57:18 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-29 09:57:18 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-29 09:57:18 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-29 09:57:48 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_Service_Detail | 2026-04-29 10:03:40 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-04-29 10:00:10 | -2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-29 10:10:03 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-29 10:04:41 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-29 10:05:40 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-29 10:09:34 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-29 10:05:40 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-29 10:04:40 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-29 10:09:35 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-29 10:13:48 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-29 10:13:15 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-29 10:10:33 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-29 10:13:16 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-29 10:11:02 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-29 10:14:49 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-29 10:10:35 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-29 10:13:48 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-29 10:18:07 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-29 10:17:10 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-29 10:17:04 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-29 10:17:11 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-29 10:21:03 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-29 10:17:33 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-04-29 10:23:50 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-29 10:27:29 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-29 10:23:52 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-29 10:23:50 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-29 10:23:52 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-29 10:23:52 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 318.5 | [CRIT] Critical |
| df_Parts_InterbranchTransfer_Raw | 2026-04-29 09:17:45 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-04-29 09:20:15 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-29 09:21:45 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-29 09:25:14 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-29 09:24:14 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-29 09:23:44 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-29 09:30:57 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-29 09:28:44 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-29 09:32:56 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-29 09:31:57 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-29 09:31:26 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-29 09:31:59 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-29 09:30:56 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-29 09:38:53 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-29 09:35:48 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-29 09:36:11 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-29 09:39:54 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-29 09:38:52 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-29 09:39:53 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-29 09:35:12 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-29 09:35:09 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-29 09:38:53 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-29 09:35:10 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-29 09:35:09 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-29 09:38:23 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-29 09:38:52 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-29 09:42:35 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-29 09:42:35 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-29 09:42:35 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-29 09:42:35 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-29 09:42:36 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-29 09:42:35 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-04-29 09:42:35 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-29 09:42:35 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-29 09:42:06 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

