# Data Freshness Report

**Generated:** 2026-07-08 08:01:29
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 81 | 80.2% |
| Stale | 0 | 0% |
| Critical | 4 | 4% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_CommodityCode | 2026-07-07 21:47:16 | 10.2 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-07-08 09:50:50 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-07-08 09:50:50 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-08 09:56:30 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-08 09:55:01 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-08 09:55:00 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-08 09:55:30 | -1.9 | [OK] Fresh |
| df_Dim_Date | 2026-07-08 09:52:56 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-08 09:56:01 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-07-08 09:53:21 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-08 09:55:40 | -1.9 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-07-08 10:01:35 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-07 14:19:30 | 17.7 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-08 10:03:23 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-08 10:02:53 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-08 09:58:52 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-08 10:04:53 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-08 10:08:41 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-08 10:09:37 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-08 10:04:53 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-08 10:09:37 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-08 10:09:07 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-08 10:09:40 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-08 10:09:11 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-08 10:04:23 | -2.1 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-08 10:12:26 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-08 10:12:21 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-08 10:15:39 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-08 10:12:23 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-08 10:15:10 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-08 10:15:39 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-08 10:15:08 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-08 10:12:55 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-08 10:11:52 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-08 10:15:09 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-08 10:18:41 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-08 10:21:03 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-08 10:21:03 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-08 10:21:04 | -2.3 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-08 10:21:04 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-08 10:21:02 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-08 10:23:03 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-08 12:34:00 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-07-07 14:02:34 | 18 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-08 09:18:14 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-08 09:20:44 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-08 09:22:14 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-08 09:23:44 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-08 09:23:44 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-08 09:24:26 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-08 09:33:25 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-08 09:29:14 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-08 09:31:56 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-08 09:32:25 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-08 09:32:25 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-08 09:31:25 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-08 09:31:26 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-08 09:38:14 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-08 09:35:38 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-08 09:36:38 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-08 09:37:08 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-08 09:35:36 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-08 09:36:07 | -1.6 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-08 09:43:39 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-08 09:40:55 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-08 09:40:55 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-08 09:43:39 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-08 09:44:09 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-08 09:44:09 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-08 09:44:39 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-08 09:43:39 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-08 09:40:26 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-08 09:40:56 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-08 09:44:09 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-07-08 09:44:09 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-08 09:41:55 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-08 09:44:09 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-08 09:40:56 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-08 09:40:56 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-08 12:02:13 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-08 12:05:15 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

