# Data Freshness Report

**Generated:** 2026-06-18 08:01:28
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
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-06-01 12:33:08 (403.5 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Franchise | 2026-06-01 12:33:08 | 403.5 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-06-17 10:01:48 | 22 | [OK] Fresh |
| df_Dim_Date | 2026-06-18 10:03:33 | -2 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-18 10:08:44 | -2.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-18 10:08:46 | -2.1 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-18 10:08:43 | -2.1 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-18 10:08:47 | -2.1 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-18 10:08:44 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-06-18 10:04:32 | -2.1 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-18 10:09:46 | -2.1 | [OK] Fresh |
| df_Dim_Part | 2026-06-18 10:06:32 | -2.1 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_ServiceTimeSheet_Audit | 2026-06-17 21:41:31 | 10.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-18 10:15:46 | -2.2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-06-18 10:12:18 | -2.2 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-18 10:16:46 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-18 10:17:16 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-18 10:17:48 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-18 10:18:16 | -2.3 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-18 10:21:59 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-18 10:23:29 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-18 10:22:58 | -2.4 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-18 10:25:44 | -2.4 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-18 10:26:45 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-18 10:22:29 | -2.4 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-18 10:26:13 | -2.4 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-18 10:25:14 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-18 10:26:14 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-18 10:22:28 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-18 10:22:27 | -2.4 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-18 10:28:58 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-18 10:29:28 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-18 10:32:57 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-18 10:29:28 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-18 10:29:28 | -2.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-18 10:29:29 | -2.5 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-18 10:35:40 | -2.6 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-18 10:37:10 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-18 10:36:10 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-18 10:35:10 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-18 10:35:40 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-18 10:35:40 | -2.6 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-18 12:33:01 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-17 21:11:59 | 10.8 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-18 09:22:15 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-18 09:17:45 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-06-18 09:21:15 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-18 09:20:16 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-18 09:25:45 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-18 09:23:45 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-18 09:45:59 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-18 09:45:31 | -1.7 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-18 09:43:17 | -1.7 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-18 09:46:00 | -1.7 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-18 09:45:29 | -1.7 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-18 09:51:14 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-18 09:49:43 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-18 09:51:13 | -1.8 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-18 09:46:30 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-18 09:49:43 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-18 09:47:29 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-18 09:49:44 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-18 09:49:43 | -1.8 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-18 09:57:12 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-18 09:53:59 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-18 09:53:59 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-18 09:57:42 | -1.9 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-18 09:57:43 | -1.9 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-18 09:57:12 | -1.9 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-18 09:57:12 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-18 09:57:12 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-06-18 09:57:13 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-18 09:53:29 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-18 09:53:29 | -1.9 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-18 09:57:43 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-18 09:54:59 | -1.9 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-18 09:57:42 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-18 09:54:08 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-18 09:53:59 | -1.9 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-18 12:02:06 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-18 12:04:38 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

