# Data Freshness Report

**Generated:** 2026-04-23 08:01:27
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

- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (174.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-17 14:51:30 (137.2 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-17 14:51:30 | 137.2 | [CRIT] Critical |
| df_Dim_Part | 2026-04-23 10:10:06 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-04-23 10:08:01 | -2.1 | [OK] Fresh |
| df_Dim_Date | 2026-04-23 10:07:01 | -2.1 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-23 10:12:20 | -2.2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-23 10:12:20 | -2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-23 10:12:20 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-23 10:12:50 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-23 10:12:21 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-23 10:13:20 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-23 10:15:42 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-23 10:21:13 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-23 10:21:13 | -2.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-23 10:20:13 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-23 10:21:13 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-23 10:22:14 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-23 10:27:55 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-23 10:26:56 | -2.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-23 10:26:25 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-23 10:26:58 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-23 10:25:55 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-23 10:26:26 | -2.4 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-23 10:30:39 | -2.5 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-23 10:32:07 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-23 10:31:07 | -2.5 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-23 10:30:07 | -2.5 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-23 10:31:05 | -2.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-23 10:34:50 | -2.6 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-23 10:38:19 | -2.6 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-23 10:35:19 | -2.6 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-23 10:35:19 | -2.6 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-23 10:34:50 | -2.6 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-23 10:35:19 | -2.6 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-04-23 10:41:05 | -2.7 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-23 10:41:04 | -2.7 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-23 10:41:34 | -2.7 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-23 10:41:05 | -2.7 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-23 10:41:04 | -2.7 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-23 10:41:05 | -2.7 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 174.5 | [CRIT] Critical |
| df_Parts_InterbranchTransfer_Raw | 2026-04-23 09:18:15 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-23 09:22:15 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-23 09:21:46 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-04-23 09:20:15 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-23 09:25:45 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-23 09:23:45 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-23 09:45:48 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-23 09:45:50 | -1.7 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-23 09:43:35 | -1.7 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-23 09:50:31 | -1.8 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-23 09:47:18 | -1.8 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-23 09:47:18 | -1.8 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-23 09:46:48 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-23 09:50:31 | -1.8 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-23 09:52:02 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-23 09:51:32 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-23 09:50:02 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-23 09:47:48 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-23 09:50:02 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-23 09:55:48 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-23 09:54:48 | -1.9 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-23 09:58:13 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-23 09:54:47 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-23 09:54:49 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-23 09:54:17 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-23 09:54:48 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-23 09:54:47 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-23 09:58:45 | -2 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-23 09:58:43 | -2 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-23 09:58:44 | -2 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-23 09:58:43 | -2 | [OK] Fresh |
| df_Technician_Raw | 2026-04-23 09:58:43 | -2 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-23 09:58:43 | -2 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-23 09:58:43 | -2 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-23 09:58:45 | -2 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

