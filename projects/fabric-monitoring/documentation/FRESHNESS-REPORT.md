# Data Freshness Report

**Generated:** 2026-07-02 08:01:28
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 79 | 79% |
| Stale | 0 | 0% |
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
| df_Dim_BranchUserAccess | 2026-07-01 10:02:13 | 22 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-02 09:58:08 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-07-02 09:56:27 | -1.9 | [OK] Fresh |
| df_Dim_Date | 2026-07-02 09:53:26 | -1.9 | [OK] Fresh |
| df_Dim_Customer | 2026-07-02 09:53:56 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-02 09:58:37 | -2 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-02 09:58:37 | -2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-02 09:59:00 | -2 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-02 09:58:37 | -2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-02 09:59:37 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-01 14:19:29 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-02 10:02:00 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-02 10:06:30 | -2.1 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-02 10:06:00 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-02 10:07:33 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-02 10:08:31 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-02 10:08:31 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-02 10:13:46 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-02 10:12:17 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-02 10:12:18 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-02 10:16:03 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-02 10:16:02 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-02 10:13:00 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-02 10:13:20 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-02 10:13:16 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-02 10:19:55 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-02 10:17:02 | -2.3 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-02 10:17:02 | -2.3 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-02 10:16:48 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-02 10:19:54 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-02 10:19:56 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-02 10:19:28 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-02 10:19:25 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-02 10:26:12 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-02 10:25:42 | -2.4 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-02 10:23:26 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-02 10:25:42 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-02 10:25:12 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-02 10:25:41 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-02 10:25:42 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-02 12:32:59 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-07-01 14:02:30 | 18 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-02 09:20:44 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-02 09:21:44 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-02 09:18:14 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-02 09:25:44 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-02 09:24:14 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-02 09:22:44 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-02 09:32:44 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-02 09:35:57 | -1.6 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-02 09:35:57 | -1.6 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-02 09:35:27 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-02 09:39:08 | -1.6 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-02 09:34:57 | -1.6 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-02 09:34:57 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-02 09:39:08 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-02 09:36:57 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-02 09:39:08 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-02 09:39:38 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-02 09:40:39 | -1.7 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-02 09:41:08 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-02 09:45:15 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-02 09:43:52 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-02 09:43:52 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-02 09:43:52 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-02 09:43:52 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-02 09:43:22 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-02 09:43:52 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-02 09:47:37 | -1.8 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-02 09:47:37 | -1.8 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-02 09:47:37 | -1.8 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-02 09:47:37 | -1.8 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-02 09:47:37 | -1.8 | [OK] Fresh |
| df_Technician_Raw | 2026-07-02 09:47:37 | -1.8 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-02 09:47:38 | -1.8 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-02 09:47:37 | -1.8 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-02 09:47:37 | -1.8 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-02 12:02:46 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-02 12:05:53 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

