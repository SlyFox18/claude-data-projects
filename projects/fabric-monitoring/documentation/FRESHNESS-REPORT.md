# Data Freshness Report

**Generated:** 2026-04-27 08:01:33
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

- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (270.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-23 19:54:02 (84.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 84.1 | [CRIT] Critical |
| df_Dim_Date | 2026-04-27 09:49:18 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-04-27 09:49:48 | -1.8 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-27 09:54:29 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-27 09:54:28 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-27 09:54:29 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-27 09:55:28 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-27 09:54:29 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-27 09:54:28 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-04-27 09:52:18 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-27 09:57:50 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-27 10:03:20 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-27 10:02:50 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-27 10:01:49 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-27 10:03:20 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-27 10:03:50 | -2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-27 10:09:43 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-27 10:08:48 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-27 10:08:18 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-27 10:08:43 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-27 10:08:23 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-27 10:08:21 | -2.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-27 10:12:25 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-27 10:12:55 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-27 10:13:55 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-27 10:11:55 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-27 10:13:24 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-27 10:16:46 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-27 10:20:38 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-27 10:16:39 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-27 10:17:09 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-27 10:16:38 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-27 10:16:39 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-04-27 10:23:23 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-27 10:23:24 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-27 10:23:54 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-27 10:23:24 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-27 10:23:25 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-27 10:22:54 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 270.5 | [CRIT] Critical |
| df_Parts_InterbranchTransfer_Raw | 2026-04-27 09:17:44 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-27 09:21:45 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-04-27 09:20:14 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-27 09:21:45 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-27 09:23:15 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-27 09:28:15 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-27 09:23:45 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-27 09:30:26 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-27 09:32:56 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-27 09:31:56 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-27 09:30:56 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-27 09:31:27 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-27 09:31:26 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-27 09:39:19 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-27 09:36:10 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-27 09:36:39 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-27 09:40:20 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-27 09:39:20 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-27 09:39:20 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-27 09:34:39 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-27 09:35:09 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-27 09:39:20 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-27 09:35:09 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-27 09:35:09 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-27 09:38:50 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-27 09:39:20 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-27 09:43:03 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-27 09:43:03 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-27 09:43:03 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-27 09:43:03 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-27 09:43:02 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-27 09:43:03 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-04-27 09:42:33 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-27 09:43:03 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-27 09:43:04 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

