# Data Freshness Report

**Generated:** 2026-07-17 08:01:27
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 80 | 78.4% |
| Stale |  | 0% |
| Critical | 5 | 4.9% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-07-07 21:47:16 (226.2 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_CommodityCode | 2026-07-07 21:47:16 | 226.2 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-07-15 10:02:07 | 46 | [WARN] Stale |
| df_Dim_Date | 2026-07-17 09:54:20 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-07-17 09:57:20 | -1.9 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-07-17 09:53:51 | -1.9 | [OK] Fresh |
| df_Dim_Customer | 2026-07-17 09:54:51 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-17 09:59:02 | -2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-17 09:59:31 | -2 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-17 09:59:31 | -2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-17 09:59:02 | -2 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-17 09:59:31 | -2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-17 10:00:31 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-16 14:18:59 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-17 10:03:07 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-17 10:07:38 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-17 10:09:19 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-17 10:09:08 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-17 10:08:37 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-17 10:09:08 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-17 10:13:27 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-17 10:13:27 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-17 10:14:58 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-17 10:14:27 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-17 10:13:58 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-17 10:14:26 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-17 10:18:40 | -2.3 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-17 10:17:40 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-17 10:21:21 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-17 10:20:52 | -2.3 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-17 10:17:09 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-17 10:20:51 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-17 10:21:21 | -2.3 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-17 10:17:39 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-17 10:17:41 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-17 10:27:04 | -2.4 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-17 10:24:51 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-17 10:28:05 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-17 10:27:05 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-17 10:27:06 | -2.4 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-17 10:22:21 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-17 10:27:05 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-17 10:27:05 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-17 12:33:32 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-07-16 14:02:33 | 18 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-17 09:21:43 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-17 09:18:13 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-17 09:20:43 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-17 09:24:13 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-17 09:24:43 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-17 09:22:43 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-17 09:32:26 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-17 09:31:56 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-17 09:29:43 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-17 09:33:27 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-17 09:31:56 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-17 09:33:56 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-17 09:40:16 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-17 09:40:16 | -1.6 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-17 09:38:04 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-17 09:40:16 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-17 09:40:16 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-17 09:41:16 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-17 09:44:28 | -1.7 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-17 09:41:46 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-17 09:44:29 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-17 09:44:28 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-17 09:45:28 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-17 09:43:58 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-17 09:43:59 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-17 09:44:28 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-17 09:47:12 | -1.8 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-17 09:47:42 | -1.8 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-17 09:47:41 | -1.8 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-17 09:47:41 | -1.8 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-17 09:48:11 | -1.8 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-17 09:47:41 | -1.8 | [OK] Fresh |
| df_Technician_Raw | 2026-07-17 09:47:41 | -1.8 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-17 09:47:42 | -1.8 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-17 09:47:41 | -1.8 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-17 12:02:06 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-17 12:05:06 | -4.1 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-07-17 12:48:12 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

