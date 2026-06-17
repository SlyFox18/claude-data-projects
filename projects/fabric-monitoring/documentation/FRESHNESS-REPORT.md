# Data Freshness Report

**Generated:** 2026-06-17 08:01:31
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 79 | 79% |
| Stale | 0 | 0% |
| Critical | 5 | 5% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-06-01 12:33:08 (379.5 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Franchise | 2026-06-01 12:33:08 | 379.5 | [CRIT] Critical |
| df_Dim_Date | 2026-06-17 09:51:38 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-06-17 09:52:09 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-17 09:56:49 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-17 09:56:48 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-17 09:56:48 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-17 09:56:48 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-17 09:56:48 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-06-17 09:54:38 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-17 09:57:48 | -1.9 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-06-17 10:01:48 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_ServiceTimeSheet_Audit | 2026-06-16 20:14:26 | 11.8 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-17 10:03:41 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-06-17 09:59:40 | -2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-17 10:09:59 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-17 10:05:41 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-17 10:10:01 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-17 10:05:41 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-17 10:09:27 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-17 10:05:41 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-17 10:09:28 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-17 10:04:41 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-17 10:09:58 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-17 10:13:44 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-17 10:13:12 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-17 10:13:15 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-17 10:14:14 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-17 10:11:01 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-17 10:13:44 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-17 10:17:24 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-17 10:16:58 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-17 10:16:54 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-17 10:20:24 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-17 10:16:24 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-17 10:16:56 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-17 10:23:39 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-17 10:22:40 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-17 10:23:10 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-17 10:23:44 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-17 10:22:39 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-17 10:23:10 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-17 12:32:58 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-16 19:01:01 | 13 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-06-17 09:21:46 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-17 09:17:46 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-17 09:20:16 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-17 09:24:46 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-17 09:24:16 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-17 09:24:16 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-17 09:32:29 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-17 09:29:16 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-17 09:31:30 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-17 09:32:00 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-17 09:32:30 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-17 09:34:00 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-17 09:33:00 | -1.5 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-17 09:39:53 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-17 09:37:42 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-17 09:39:53 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-17 09:40:24 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-17 09:39:54 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-17 09:37:11 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-17 09:36:11 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-17 09:39:53 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-17 09:39:53 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-17 09:36:11 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-17 09:36:11 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-17 09:36:12 | -1.6 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-17 09:43:37 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-17 09:43:37 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-17 09:43:37 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-17 09:44:07 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-17 09:44:07 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-17 09:44:07 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-06-17 09:44:08 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-17 09:41:23 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-17 09:43:37 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-17 09:46:15 | -1.8 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-17 12:02:09 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-17 12:04:39 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

