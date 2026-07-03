# Data Freshness Report

**Generated:** 2026-07-03 08:01:38
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 78 | 78% |
| Stale |  | 0% |
| Critical | 3 | 3% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-07-01 10:02:13 | 46 | [WARN] Stale |
| df_Dim_Date | 2026-07-03 09:51:35 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-03 09:57:52 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-03 09:56:21 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-03 09:56:49 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-03 09:56:50 | -1.9 | [OK] Fresh |
| df_Dim_Customer | 2026-07-03 09:52:36 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-03 09:56:51 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-07-03 09:54:36 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-03 09:56:51 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-02 14:19:28 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-03 10:00:15 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-03 10:04:45 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-03 10:04:44 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-03 10:10:05 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-03 10:05:44 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-03 10:06:14 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-03 10:10:05 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-03 10:06:14 | -2.1 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-03 10:14:27 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-03 10:15:27 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-03 10:12:08 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-03 10:15:28 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-03 10:14:28 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-03 10:11:04 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-03 10:12:05 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-03 10:15:28 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-03 10:10:32 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-03 10:21:43 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-03 10:17:40 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-03 10:18:12 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-03 10:18:13 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-03 10:18:43 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-03 10:18:26 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-03 10:25:10 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-03 10:24:12 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-03 10:24:03 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-03 10:24:01 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-03 10:24:03 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-03 10:24:02 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-03 12:33:30 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-07-02 14:03:33 | 18 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-03 09:22:15 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-03 09:18:15 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-03 09:20:45 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-03 09:22:15 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-03 09:24:17 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-03 09:23:45 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-03 09:34:31 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-03 09:30:15 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-03 09:33:33 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-03 09:32:30 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-03 09:33:31 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-03 09:33:31 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-03 09:32:31 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-03 09:36:45 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-03 09:37:44 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-03 09:40:28 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-03 09:38:14 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-03 09:36:43 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-03 09:40:28 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-03 09:36:44 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-03 09:36:43 | -1.6 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-03 09:45:52 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-03 09:45:19 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-03 09:45:49 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-03 09:45:49 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-03 09:45:49 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-03 09:45:49 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-03 09:45:50 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-03 09:43:34 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-03 09:40:57 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-07-03 09:45:49 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-03 09:40:57 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-03 09:40:57 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-03 09:45:49 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-03 09:41:57 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-03 12:02:46 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-03 12:05:59 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

