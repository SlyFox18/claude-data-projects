# Data Freshness Report

**Generated:** 2026-06-19 08:01:31
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 78 | 78% |
| Stale |  | 0% |
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
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-06-01 12:33:08 (427.5 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Franchise | 2026-06-01 12:33:08 | 427.5 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-06-17 10:01:48 | 46 | [WARN] Stale |
| df_Dim_Part | 2026-06-19 09:51:46 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-06-19 09:49:16 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-06-19 09:48:46 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-19 09:54:02 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-19 09:54:03 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-19 09:54:06 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-19 09:54:06 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-19 09:55:05 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-19 09:54:02 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_PartsAdjustments | 2026-06-18 10:26:13 | 21.6 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-18 10:26:14 | 21.6 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-18 10:25:14 | 21.6 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-18 10:25:44 | 21.6 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-18 10:29:29 | 21.5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-18 10:28:58 | 21.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-18 10:29:28 | 21.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-18 10:29:28 | 21.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-18 10:32:57 | 21.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-18 10:29:28 | 21.5 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-18 10:35:40 | 21.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-18 10:35:40 | 21.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-18 10:37:10 | 21.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-18 10:35:40 | 21.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-18 10:35:10 | 21.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-18 10:36:10 | 21.4 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-18 16:15:54 | 15.8 | [OK] Fresh |
| df_Fact_ServiceTimeSheet_Audit | 2026-06-18 21:06:53 | 10.9 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-06-19 09:57:27 | -1.9 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-19 10:00:57 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-19 10:02:27 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-19 10:02:58 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-19 10:01:59 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-19 10:02:57 | -2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-19 10:06:42 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-19 10:07:14 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-19 10:08:14 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-19 10:14:54 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-19 10:22:19 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-19 10:19:44 | -2.3 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-19 12:32:57 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-18 14:02:33 | 18 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-06-19 09:21:44 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-19 09:17:44 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-19 09:21:44 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-19 09:20:15 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-19 09:23:14 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-19 09:23:44 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-19 09:28:45 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-19 09:31:56 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-19 09:30:56 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-19 09:31:27 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-19 09:31:55 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-19 09:30:56 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-19 09:32:56 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-19 09:36:38 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-19 09:36:08 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-19 09:39:20 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-19 09:39:20 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-19 09:35:08 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-19 09:39:20 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-19 09:39:04 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-19 09:40:20 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-19 09:35:08 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-19 09:38:49 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-19 09:35:08 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-19 09:34:37 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-19 09:38:50 | -1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-19 09:43:02 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-19 09:42:33 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-19 09:42:32 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-19 09:43:02 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-19 09:42:32 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-06-19 09:43:02 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-19 09:42:32 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-19 09:43:02 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-19 09:43:02 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-19 12:02:26 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-19 12:05:49 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

