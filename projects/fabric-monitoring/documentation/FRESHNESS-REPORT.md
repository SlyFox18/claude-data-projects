# Data Freshness Report

**Generated:** 2026-07-21 08:01:32
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
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-07-07 21:47:16 (322.2 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_CommodityCode | 2026-07-07 21:47:16 | 322.2 | [CRIT] Critical |
| df_Dim_Technicans | 2026-07-21 09:58:03 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-21 09:58:03 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-07-21 09:56:22 | -1.9 | [OK] Fresh |
| df_Dim_Date | 2026-07-21 09:52:54 | -1.9 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-07-21 09:52:53 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-21 09:58:03 | -1.9 | [OK] Fresh |
| df_Dim_Customer | 2026-07-21 09:53:53 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-21 09:58:33 | -2 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-07-21 10:01:39 | -2 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-21 09:58:33 | -2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-21 09:59:33 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-20 14:19:58 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-21 10:01:54 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-21 10:06:24 | -2.1 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-21 10:05:24 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-21 10:07:26 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-21 10:07:54 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-21 10:07:24 | -2.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-21 10:14:55 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-21 10:12:40 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-21 10:11:40 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-21 10:14:54 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-21 10:11:42 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-21 10:15:53 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-21 10:15:24 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-21 10:12:40 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-21 10:12:40 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-21 10:15:54 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-21 10:12:10 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-21 10:22:07 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-21 10:18:06 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-21 10:18:36 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-21 10:18:36 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-21 10:18:36 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-21 10:18:07 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-21 10:25:25 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-21 10:24:24 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-21 10:24:25 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-21 10:24:25 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-21 10:24:25 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-21 10:24:24 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-21 12:33:34 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-07-20 14:03:12 | 18 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-21 09:18:14 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-21 09:22:14 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-21 09:22:13 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-21 09:20:44 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-21 09:26:53 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-21 09:23:44 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-21 09:29:43 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-21 09:33:25 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-21 09:33:26 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-21 09:33:55 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-21 09:38:44 | -1.6 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-21 09:35:02 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-21 09:39:44 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-21 09:38:43 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-21 09:39:14 | -1.6 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-21 09:36:03 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-21 09:38:44 | -1.6 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-21 09:36:32 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-21 09:40:43 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-21 09:43:26 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-21 09:43:24 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-21 09:43:25 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-21 09:44:25 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-21 09:42:54 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-21 09:42:54 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-21 09:43:24 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-21 09:46:38 | -1.8 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-21 09:46:38 | -1.8 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-21 09:46:38 | -1.8 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-21 09:46:38 | -1.8 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-21 09:46:38 | -1.8 | [OK] Fresh |
| df_Technician_Raw | 2026-07-21 09:46:38 | -1.8 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-21 09:46:38 | -1.8 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-21 09:47:08 | -1.8 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-21 09:47:08 | -1.8 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-21 12:02:51 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-21 12:05:21 | -4.1 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-07-21 12:48:51 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

