# Data Freshness Report

**Generated:** 2026-05-04 08:01:21
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

- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (438.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-23 19:54:02 (252.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 252.1 | [CRIT] Critical |
| df_Dim_Date | 2026-05-04 09:48:53 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-05-04 09:49:55 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-04 09:57:06 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-04 09:55:07 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-04 09:55:35 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-04 09:55:36 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-04 09:55:35 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-05-04 09:53:25 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-04 10:00:15 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-05-04 10:03:34 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-04 10:07:44 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-04 10:08:03 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-04 10:09:38 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-04 10:09:06 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-04 10:16:03 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-04 10:11:16 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-04 10:15:07 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-04 10:16:04 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-04 10:15:31 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-04 10:15:01 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-04 10:19:17 | -2.3 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-04 10:19:17 | -2.3 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-04 10:20:17 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-04 10:19:48 | -2.3 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-04 10:16:33 | -2.3 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-04 10:19:47 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-04 10:23:16 | -2.4 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-04 10:22:29 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-04 10:22:29 | -2.4 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-04 10:22:30 | -2.4 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-04 10:22:59 | -2.4 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-04 10:26:34 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-04 10:29:48 | -2.5 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-04 10:28:48 | -2.5 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-04 10:29:18 | -2.5 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-04 10:29:17 | -2.5 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-04 10:29:19 | -2.5 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-04 10:29:18 | -2.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 438.5 | [CRIT] Critical |
| df_Parts_InterbranchTransfer_Raw | 2026-05-04 09:17:44 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-04 09:21:44 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-04 09:21:44 | -1.3 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-04 09:27:48 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-04 09:23:44 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-04 09:23:46 | -1.4 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-04 09:26:22 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-04 09:30:30 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-04 09:31:00 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-04 09:31:01 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-04 09:34:11 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-04 09:30:00 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-04 09:29:59 | -1.5 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-04 09:34:11 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-04 09:31:59 | -1.5 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-04 09:33:42 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-04 09:34:11 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-04 09:39:27 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-04 09:35:11 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-04 09:40:00 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-04 09:38:27 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-04 09:35:43 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-04 09:37:56 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-04 09:38:26 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-04 09:38:26 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-04 09:37:57 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-04 09:42:44 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-04 09:42:43 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-04 09:43:13 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-04 09:42:43 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-05-04 09:42:43 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-04 09:42:43 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-04 09:42:43 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-04 09:42:13 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-04 09:42:43 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

