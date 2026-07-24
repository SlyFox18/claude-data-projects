# Data Freshness Report

**Generated:** 2026-07-24 08:01:25
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 79 | 77.5% |
| Stale | 2 | 2% |
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
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-07-07 21:47:16 (394.2 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_InMaster_PartsLookup_Raw** (RawSource) - Last refreshed: 2026-07-21 12:48:51 (67.2 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-07-22 10:02:00 (46 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_CommodityCode | 2026-07-07 21:47:16 | 394.2 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-07-22 10:02:00 | 46 | [WARN] Stale |
| df_Dim_Date | 2026-07-23 09:51:46 | 22.2 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-07-23 09:51:46 | 22.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-23 09:57:58 | 22.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-23 09:56:28 | 22.1 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-23 09:56:28 | 22.1 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-23 09:56:58 | 22.1 | [OK] Fresh |
| df_Dim_Customer | 2026-07-23 09:52:46 | 22.1 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-23 09:56:28 | 22.1 | [OK] Fresh |
| df_Dim_Part | 2026-07-23 09:54:46 | 22.1 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-23 09:56:58 | 22.1 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Service_Detail | 2026-07-23 10:03:51 | 22 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-07-23 10:00:20 | 22 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-23 10:04:50 | 21.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-23 10:05:21 | 21.9 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-23 10:06:20 | 21.9 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-23 10:05:51 | 21.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-23 10:10:13 | 21.9 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-23 10:11:43 | 21.8 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-23 10:10:13 | 21.8 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-23 10:14:11 | 21.8 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-23 10:13:55 | 21.8 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-23 10:14:56 | 21.8 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-23 10:14:24 | 21.8 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-23 10:14:26 | 21.8 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-23 10:11:13 | 21.8 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-23 10:10:43 | 21.8 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-23 10:11:13 | 21.8 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-23 10:17:10 | 21.7 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-23 10:17:39 | 21.7 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-23 10:21:09 | 21.7 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-23 10:17:09 | 21.7 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-23 10:17:09 | 21.7 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-23 10:17:10 | 21.7 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-23 10:24:24 | 21.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-23 10:23:24 | 21.6 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-23 10:23:23 | 21.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-23 10:24:04 | 21.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-23 10:23:23 | 21.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-23 10:23:25 | 21.6 | [OK] Fresh |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-23 14:19:58 | 17.7 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-24 12:30:22 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_PartsLookup_Raw | 2026-07-21 12:48:51 | 67.2 | [WARN] Stale |
| df_InMaster_Raw | 2026-07-23 09:36:29 | 22.4 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-23 09:38:40 | 22.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-23 09:34:29 | 22.4 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-23 09:38:40 | 22.4 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-23 09:40:11 | 22.4 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-23 09:38:40 | 22.4 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-23 09:38:41 | 22.4 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-23 09:40:09 | 22.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-23 09:34:28 | 22.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-23 09:35:29 | 22.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-23 09:35:29 | 22.4 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-23 09:35:28 | 22.4 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-23 09:42:22 | 22.3 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-23 09:42:52 | 22.3 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-23 09:42:52 | 22.3 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-23 09:42:52 | 22.3 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-23 09:42:52 | 22.3 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-23 09:45:35 | 22.3 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-23 09:43:53 | 22.3 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-23 09:45:35 | 22.3 | [OK] Fresh |
| df_Technician_Raw | 2026-07-23 09:46:05 | 22.3 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-23 09:42:52 | 22.3 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-23 09:46:05 | 22.3 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-23 09:45:35 | 22.3 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-23 09:46:05 | 22.3 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-23 09:46:05 | 22.3 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-23 09:46:05 | 22.3 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-23 09:46:05 | 22.3 | [OK] Fresh |
| df_ServiceTimeSheets_Raw | 2026-07-23 14:03:14 | 18 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-24 09:17:12 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-24 09:17:12 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-24 09:17:12 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-24 09:17:08 | -1.3 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-24 09:18:14 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-24 09:17:13 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-07-24 09:17:13 | -1.3 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-24 12:02:20 | -4 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-24 12:04:14 | -4 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

