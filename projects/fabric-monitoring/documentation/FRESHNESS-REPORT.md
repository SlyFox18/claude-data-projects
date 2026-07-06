# Data Freshness Report

**Generated:** 2026-07-06 08:01:32
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 76 | 76% |
| Stale | 2 | 2% |
| Critical | 5 | 5% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-07-01 10:02:13 (118 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-07-03 14:03:03 (66 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-07-03 14:19:28 (65.7 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-07-01 10:02:13 | 118 | [CRIT] Critical |
| df_Dim_Date | 2026-07-06 09:51:07 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-07-06 09:51:38 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-06 09:56:20 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-06 09:55:49 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-06 09:55:49 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-06 09:57:18 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-06 09:56:19 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-06 09:56:20 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-07-06 09:54:09 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-03 14:19:28 | 65.7 | [WARN] Stale |
| df_Fact_Inventory | 2026-07-06 10:04:12 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-06 10:03:12 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-06 09:59:42 | -2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-06 10:10:18 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-06 10:04:42 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-06 10:10:18 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-06 10:09:29 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-06 10:05:41 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-06 10:09:29 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-06 10:05:16 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-06 10:10:32 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-06 10:17:07 | -2.3 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-06 10:20:23 | -2.3 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-06 10:19:51 | -2.3 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-06 10:19:20 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-06 10:20:21 | -2.3 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-06 10:19:49 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-06 10:22:39 | -2.4 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-06 10:22:40 | -2.4 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-06 10:23:10 | -2.4 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-06 10:27:13 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-06 10:23:08 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-06 10:22:38 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-06 10:30:28 | -2.5 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-06 10:29:28 | -2.5 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-06 10:29:30 | -2.5 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-06 10:29:27 | -2.5 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-06 10:29:28 | -2.5 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-06 10:29:30 | -2.5 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-06 12:33:01 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-07-03 14:03:03 | 66 | [WARN] Stale |
| df_Parts_InterbranchTransfer_Raw | 2026-07-06 09:18:16 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-06 09:22:14 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-06 09:21:45 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-06 09:20:45 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-06 09:23:44 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-06 09:24:15 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-06 09:32:28 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-06 09:30:15 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-06 09:33:28 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-06 09:32:58 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-06 09:33:28 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-06 09:32:58 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-06 09:37:41 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-06 09:36:41 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-06 09:38:41 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-06 09:36:41 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-06 09:36:41 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-06 09:34:28 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-06 09:39:18 | -1.6 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-06 09:45:14 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-06 09:42:15 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-06 09:42:01 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-06 09:45:13 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-06 09:45:14 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-06 09:45:13 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-06 09:44:43 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-06 09:45:14 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-07-06 09:45:13 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-06 09:41:32 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-06 09:45:13 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-06 09:41:31 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-06 09:43:01 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-06 09:45:14 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-06 09:42:01 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-06 09:42:16 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-06 12:02:35 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-06 12:06:31 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

