# Data Freshness Report

**Generated:** 2026-06-09 08:01:34
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
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-06-01 12:33:08 (187.5 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Franchise | 2026-06-01 12:33:08 | 187.5 | [CRIT] Critical |
| df_Dim_Part | 2026-06-09 09:52:02 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-06-09 09:49:32 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-06-09 09:48:34 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-09 09:54:15 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-09 09:54:15 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-09 09:54:15 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-09 09:54:15 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-09 09:54:46 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-09 09:54:16 | -1.9 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-06-09 10:02:01 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_ServiceTimeSheet_Audit | 2026-06-08 14:17:59 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-06-09 09:57:24 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-09 10:02:09 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-09 10:01:39 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-09 10:02:09 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-09 10:00:40 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-09 10:21:20 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-09 10:26:31 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-09 10:26:01 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-09 10:25:31 | -2.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-09 10:25:33 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-09 10:26:33 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-09 10:26:02 | -2.4 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-09 10:29:56 | -2.5 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-09 10:28:56 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-09 10:32:13 | -2.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-09 10:32:10 | -2.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-09 10:32:09 | -2.5 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-09 10:29:25 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-09 10:32:40 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-09 10:32:10 | -2.5 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-09 10:28:54 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-09 10:29:25 | -2.5 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-09 10:39:54 | -2.6 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-09 10:36:40 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-09 10:39:25 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-09 10:39:25 | -2.6 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-09 10:39:25 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-09 10:39:26 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-09 10:39:24 | -2.6 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-09 12:32:59 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-08 14:03:03 | 18 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-06-09 09:21:45 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-09 09:17:44 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-09 09:21:45 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-09 09:20:44 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-09 09:23:45 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-09 09:28:15 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-09 09:23:45 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-09 09:30:58 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-09 09:30:57 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-09 09:31:26 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-09 09:31:27 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-09 09:30:29 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-09 09:32:27 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-09 09:36:42 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-09 09:35:11 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-09 09:39:25 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-09 09:39:25 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-09 09:34:41 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-09 09:39:24 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-09 09:39:25 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-09 09:40:29 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-09 09:34:41 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-09 09:39:25 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-09 09:34:41 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-09 09:35:11 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-09 09:38:54 | -1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-09 09:43:12 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-09 09:43:12 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-09 09:43:12 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-09 09:43:12 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-09 09:43:12 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-06-09 09:42:42 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-09 09:43:13 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-09 09:43:12 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-09 09:42:42 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-09 12:03:24 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-09 12:04:50 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

