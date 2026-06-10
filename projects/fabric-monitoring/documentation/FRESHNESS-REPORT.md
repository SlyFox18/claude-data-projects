# Data Freshness Report

**Generated:** 2026-06-10 08:01:33
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
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-06-01 12:33:08 (211.5 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Franchise | 2026-06-01 12:33:08 | 211.5 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-06-10 10:00:59 | -2 | [OK] Fresh |
| df_Dim_Customer | 2026-06-10 10:03:51 | -2 | [OK] Fresh |
| df_Dim_Date | 2026-06-10 10:03:10 | -2 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-10 10:08:09 | -2.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-10 10:07:36 | -2.1 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-10 10:08:36 | -2.1 | [OK] Fresh |
| df_Dim_Part | 2026-06-10 10:05:52 | -2.1 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-10 10:08:07 | -2.1 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-10 10:08:06 | -2.1 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-10 10:08:36 | -2.1 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_ServiceTimeSheet_Audit | 2026-06-09 14:18:00 | 17.7 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-10 10:15:30 | -2.2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-10 10:16:00 | -2.2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-06-10 10:11:28 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-10 10:20:54 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-10 10:16:28 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-10 10:21:23 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-10 10:16:31 | -2.3 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-10 10:20:23 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-10 10:16:35 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-10 10:20:53 | -2.3 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-10 10:19:52 | -2.3 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-10 10:20:51 | -2.3 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-10 10:24:35 | -2.4 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-10 10:24:05 | -2.4 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-10 10:27:34 | -2.4 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-10 10:27:32 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-10 10:24:05 | -2.4 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-10 10:27:41 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-10 10:27:37 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-10 10:27:31 | -2.4 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-10 10:23:05 | -2.4 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-10 10:23:35 | -2.4 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-10 10:31:02 | -2.5 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-10 10:34:07 | -2.5 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-10 10:33:37 | -2.5 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-10 10:34:07 | -2.5 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-10 10:34:05 | -2.5 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-10 10:34:07 | -2.5 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-10 10:35:19 | -2.6 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-10 12:32:58 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-09 14:02:33 | 18 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-06-10 09:21:44 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-10 09:17:44 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-10 09:20:14 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-10 09:25:13 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-10 09:24:14 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-10 09:24:14 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-10 09:45:03 | -1.7 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-10 09:42:42 | -1.7 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-10 09:45:03 | -1.7 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-10 09:45:35 | -1.7 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-10 09:45:33 | -1.7 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-10 09:46:03 | -1.7 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-10 09:50:49 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-10 09:49:19 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-10 09:49:19 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-10 09:50:19 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-10 09:47:03 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-10 09:49:21 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-10 09:49:19 | -1.8 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-10 09:56:48 | -1.9 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-10 09:56:47 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-10 09:53:33 | -1.9 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-10 09:57:17 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-10 09:57:17 | -1.9 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-10 09:57:19 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-10 09:57:17 | -1.9 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-10 09:57:17 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-10 09:54:03 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-10 09:53:33 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-10 09:53:02 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-06-10 09:57:17 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-10 09:53:36 | -1.9 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-10 09:57:17 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-10 09:54:32 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-10 09:53:03 | -1.9 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-10 12:02:08 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-10 12:05:09 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

