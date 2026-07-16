# Data Freshness Report

**Generated:** 2026-07-16 08:01:30
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 81 | 79.4% |
| Stale | 0 | 0% |
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
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-07-07 21:47:16 (202.2 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_CommodityCode | 2026-07-07 21:47:16 | 202.2 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-07-15 10:02:07 | 22 | [OK] Fresh |
| df_Dim_Date | 2026-07-16 09:51:24 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-07-16 09:51:54 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-07-16 09:51:24 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-16 09:56:33 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-16 09:56:14 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-16 09:56:34 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-16 09:57:34 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-16 09:56:34 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-16 09:56:33 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-07-16 09:54:24 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-15 14:19:31 | 17.7 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-16 10:03:25 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-16 09:59:25 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-16 10:04:56 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-16 10:10:09 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-16 10:10:10 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-16 10:05:26 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-16 10:09:13 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-16 10:09:24 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-16 10:04:26 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-16 10:10:10 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-16 10:04:56 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-16 10:09:11 | -2.1 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-16 10:12:24 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-16 10:13:26 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-16 10:13:54 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-16 10:16:07 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-16 10:12:24 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-16 10:13:27 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-16 10:16:07 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-16 10:16:07 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-16 10:16:07 | -2.2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-16 10:22:19 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-16 10:21:50 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-16 10:19:37 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-16 10:21:49 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-16 10:16:37 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-16 10:21:49 | -2.3 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-16 10:21:50 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-16 10:21:50 | -2.3 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-16 12:33:01 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-07-15 14:03:45 | 18 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-16 09:21:46 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-16 09:20:46 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-16 09:18:16 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-16 09:24:16 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-16 09:26:16 | -1.4 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-16 09:34:01 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-16 09:33:30 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-16 09:31:16 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-16 09:33:30 | -1.5 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-16 09:29:31 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-16 09:34:31 | -1.6 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-16 09:34:30 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-16 09:37:43 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-16 09:39:12 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-16 09:39:13 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-16 09:37:42 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-16 09:37:43 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-16 09:37:55 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-16 09:35:30 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-16 09:42:04 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-16 09:45:06 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-16 09:45:07 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-16 09:41:24 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-16 09:45:06 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-16 09:45:11 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-16 09:45:06 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-16 09:45:07 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-16 09:44:37 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-07-16 09:45:06 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-16 09:41:24 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-16 09:45:06 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-16 09:41:54 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-16 09:42:54 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-16 09:41:24 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-16 09:41:54 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-16 12:02:16 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-16 12:05:14 | -4.1 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-07-16 12:48:42 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

