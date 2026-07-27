# Data Freshness Report

**Generated:** 2026-07-27 08:01:34
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 77 | 75.5% |
| Stale | 2 | 2% |
| Critical | 8 | 7.8% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-07-07 21:47:16 (466.2 hours ago)
- **df_InMaster_PartsLookup_Raw** (RawSource) - Last refreshed: 2026-07-21 12:48:51 (139.2 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-07-22 10:02:00 (118 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-07-24 14:02:08 (66 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-07-24 14:20:04 (65.7 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_CommodityCode | 2026-07-07 21:47:16 | 466.2 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-07-22 10:02:00 | 118 | [CRIT] Critical |
| df_Dim_Date | 2026-07-27 09:50:30 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-07-27 09:51:31 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-07-27 09:50:31 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-07-27 09:51:01 | -1.8 | [OK] Fresh |
| df_Dim_Salesperson | 2026-07-27 09:53:12 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-07-27 09:53:12 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-07-27 09:53:12 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-07-27 09:53:12 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-07-27 09:53:43 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-07-27 09:53:42 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-24 14:20:04 | 65.7 | [WARN] Stale |
| df_FactPartTransactions_Incremental | 2026-07-27 09:56:09 | -1.9 | [OK] Fresh |
| df_Fact_Inventory | 2026-07-27 09:56:39 | -1.9 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-07-27 09:58:09 | -1.9 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-07-27 09:57:09 | -1.9 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-07-27 09:57:39 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-07-27 09:59:39 | -2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-07-27 10:01:50 | -2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-07-27 10:03:21 | -2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-07-27 10:02:21 | -2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-07-27 10:01:51 | -2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-07-27 10:02:50 | -2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-07-27 10:07:05 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-07-27 10:07:04 | -2.1 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-07-27 10:09:20 | -2.1 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-07-27 10:06:40 | -2.1 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-07-27 10:09:20 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-07-27 10:04:21 | -2.1 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-07-27 10:08:50 | -2.1 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-07-27 10:09:21 | -2.1 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-07-27 10:09:20 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-07-27 10:07:04 | -2.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-07-27 10:06:34 | -2.1 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-07-27 10:15:39 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-07-27 10:13:20 | -2.2 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-07-27 10:15:40 | -2.2 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-07-27 10:15:39 | -2.2 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-07-27 10:15:39 | -2.2 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-07-27 10:15:39 | -2.2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-07-27 10:16:39 | -2.3 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-07-27 12:32:43 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_PartsLookup_Raw | 2026-07-21 12:48:51 | 139.2 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-07-24 14:02:08 | 66 | [WARN] Stale |
| df_InHist_PmManage_Raw | 2026-07-27 09:21:53 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-07-27 09:22:23 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-07-27 09:18:23 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-07-27 09:20:23 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-07-27 09:23:53 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-07-27 09:23:31 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-07-27 09:33:39 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-07-27 09:33:38 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-07-27 09:34:08 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-07-27 09:31:23 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-07-27 09:37:51 | -1.6 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-07-27 09:34:40 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-07-27 09:37:50 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-07-27 09:38:51 | -1.6 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-07-27 09:34:38 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-07-27 09:38:50 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-07-27 09:37:21 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-07-27 09:35:39 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-07-27 09:37:51 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-07-27 09:41:33 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-07-27 09:42:15 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-07-27 09:44:30 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-07-27 09:44:01 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-07-27 09:44:32 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-07-27 09:44:30 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-07-27 09:44:00 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-07-27 09:44:30 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-07-27 09:44:31 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-07-27 09:41:03 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-07-27 09:44:30 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-07-27 09:44:00 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-07-27 09:41:03 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-07-27 09:41:33 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-07-27 09:41:03 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-07-27 09:41:09 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-07-27 12:02:54 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-07-27 12:04:54 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

