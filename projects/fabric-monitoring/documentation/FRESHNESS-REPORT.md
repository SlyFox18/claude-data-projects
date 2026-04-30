# Data Freshness Report

**Generated:** 2026-04-30 08:01:29
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

- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (342.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-23 19:54:02 (156.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 156.1 | [CRIT] Critical |
| df_Dim_Part | 2026-04-30 10:08:27 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-04-30 10:06:37 | -2.1 | [OK] Fresh |
| df_Dim_Date | 2026-04-30 10:05:25 | -2.1 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-30 10:10:48 | -2.2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-30 10:10:41 | -2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-30 10:10:41 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-30 10:10:41 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-30 10:10:45 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-30 10:11:43 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-30 10:14:12 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-30 10:19:09 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-30 10:18:41 | -2.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-30 10:17:40 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-30 10:19:40 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-30 10:20:08 | -2.3 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-30 10:24:51 | -2.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-30 10:23:51 | -2.4 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-30 10:27:39 | -2.4 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-30 10:25:21 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-30 10:24:21 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-30 10:23:51 | -2.4 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-30 10:27:39 | -2.4 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-30 10:28:09 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-30 10:24:21 | -2.4 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-30 10:28:40 | -2.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-30 10:31:22 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-30 10:31:22 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-30 10:31:24 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-30 10:30:54 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-30 10:28:39 | -2.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-30 10:31:21 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-30 10:35:21 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-30 10:38:07 | -2.6 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-04-30 10:38:08 | -2.6 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-30 10:39:08 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-30 10:37:37 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-30 10:38:41 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-30 10:38:07 | -2.6 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 342.5 | [CRIT] Critical |
| df_Parts_InterbranchTransfer_Raw | 2026-04-30 09:17:44 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-30 09:21:43 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-04-30 09:20:13 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-30 09:22:13 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-30 09:25:15 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-30 09:23:16 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-30 09:43:09 | -1.7 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-30 09:45:21 | -1.7 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-30 09:46:21 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-30 09:45:21 | -1.7 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-30 09:46:21 | -1.7 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-30 09:45:52 | -1.7 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-30 09:49:32 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-30 09:51:32 | -1.8 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-30 09:51:03 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-30 09:49:32 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-30 09:47:20 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-30 09:49:32 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-30 09:49:32 | -1.8 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-30 09:54:14 | -1.9 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-30 09:57:25 | -1.9 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-30 09:57:26 | -1.9 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-30 09:57:25 | -1.9 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-30 09:58:00 | -1.9 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-30 09:57:55 | -1.9 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-30 09:57:25 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-04-30 09:57:55 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-30 09:54:13 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-30 09:54:14 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-30 09:54:18 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-30 09:54:14 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-30 09:55:14 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-30 09:54:14 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-30 09:58:25 | -2 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-30 09:58:25 | -2 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

