# Data Freshness Report

**Generated:** 2026-05-05 08:01:23
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 75 | 81.5% |
| Stale | 0 | 0% |
| Critical | 2 | 2.2% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (462.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-04-23 19:54:02 (276.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 276.1 | [CRIT] Critical |
| df_Dim_Part | 2026-05-05 09:51:50 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-05-05 09:50:06 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-05-05 09:48:50 | -1.8 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-05 09:54:00 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-05 09:54:00 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-05 09:54:00 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-05 09:54:01 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-05 09:54:00 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-05 09:55:01 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | Error | 0 | [?] Error |
| df_FactPartTransactions_Incremental | 2026-05-05 09:57:52 | -1.9 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-05 10:03:22 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-05 10:00:52 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-05 10:02:23 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-05 10:03:22 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-05 10:02:22 | -2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-05 10:07:19 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-05 10:08:19 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-05 10:07:20 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-05 10:08:26 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-05 10:07:52 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-05 10:08:21 | -2.1 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-05 10:11:44 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-05 10:11:43 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-05 10:14:29 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-05 10:14:30 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-05 10:13:58 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-05 10:11:44 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-05 10:14:28 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-05 10:14:29 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-05 10:10:44 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-05 10:11:43 | -2.2 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-05 10:20:50 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-05 10:21:20 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-05 10:17:59 | -2.3 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-05 10:20:50 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-05 10:20:20 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-05 10:20:51 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-05 10:20:50 | -2.3 | [OK] Fresh |
| df_Fact_OpenOrderParts | 2026-05-05 13:00:58 | -5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 462.5 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-05-04 17:29:11 | 14.5 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-05 09:17:44 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-05 09:20:14 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-05 09:21:14 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-05 09:21:44 | -1.3 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-05 09:28:16 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-05 09:23:14 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-05 09:23:14 | -1.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-05 09:31:30 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-05 09:31:30 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-05 09:31:30 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-05 09:30:29 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-05 09:30:30 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-05 09:32:29 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-05 09:38:59 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-05 09:35:43 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-05 09:36:16 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-05 09:38:58 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-05 09:38:58 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-05 09:39:59 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-05 09:35:13 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-05 09:34:43 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-05 09:39:00 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-05 09:34:43 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-05 09:34:44 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-05 09:38:29 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-05 09:38:58 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-05 09:42:42 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-05 09:42:42 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-05 09:42:11 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-05 09:43:11 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-05 09:42:43 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-05 09:42:41 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-05-05 09:42:41 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-05 09:42:43 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-05 09:42:41 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

