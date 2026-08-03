# Data Freshness Report

**Generated:** 2026-08-03 08:01:44
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 78 | 76.5% |
| Stale | 3 | 2.9% |
| Critical | 10 | 9.8% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-07-29 10:01:34 (118 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-07-31 14:03:10 (66 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-07-31 14:19:28 (65.7 hours ago)
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-08-01 12:35:04 (43.4 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-07-29 10:01:34 | 118 | [CRIT] Critical |
| df_Dim_CommodityCode | 2026-08-01 12:35:04 | 43.4 | [WARN] Stale |
| df_Dim_Salesperson | 2026-08-03 09:52:12 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-03 09:52:12 | -1.8 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-03 09:52:12 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-03 09:52:12 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-08-03 09:49:04 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-08-03 09:49:03 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-03 09:48:33 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-08-03 09:50:31 | -1.8 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-08-03 09:52:42 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-03 09:52:42 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-07-31 14:19:28 | 65.7 | [WARN] Stale |
| df_FactPartTransactions_Incremental | 2026-08-03 09:55:02 | -1.9 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-08-03 09:56:33 | -1.9 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-03 09:55:32 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-03 09:58:33 | -1.9 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-03 09:56:33 | -1.9 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-03 09:55:42 | -1.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-03 10:00:43 | -2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-03 10:02:13 | -2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-03 10:02:42 | -2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-03 10:00:43 | -2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-03 10:01:43 | -2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-03 10:01:13 | -2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-03 10:05:27 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-03 10:04:57 | -2.1 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-03 10:08:49 | -2.1 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-03 10:05:00 | -2.1 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-03 10:08:48 | -2.1 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-03 10:08:48 | -2.1 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-08-03 10:09:18 | -2.1 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-03 10:08:48 | -2.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-03 10:04:56 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-03 10:05:28 | -2.1 | [OK] Fresh |
| df_Fact_Transfers | 2026-08-03 10:12:49 | -2.2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-08-03 10:15:33 | -2.2 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-08-03 10:14:32 | -2.2 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-08-03 10:15:02 | -2.2 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-08-03 10:14:32 | -2.2 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-03 10:14:32 | -2.2 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-03 10:15:03 | -2.2 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-08-03 12:32:11 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-07-31 14:03:10 | 66 | [WARN] Stale |
| df_InHist_PmManage_Raw | 2026-08-03 09:21:51 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-03 09:17:51 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-03 09:22:21 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-03 09:20:21 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-03 09:22:51 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-03 09:24:21 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-03 09:30:51 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-03 09:33:32 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-03 09:33:33 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-03 09:33:33 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-03 09:34:04 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-03 09:33:32 | -1.5 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-03 09:40:26 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-03 09:36:55 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-03 09:38:44 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-03 09:37:12 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-03 09:37:42 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-03 09:37:12 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-03 09:35:02 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-03 09:36:43 | -1.6 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-03 09:43:07 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-03 09:40:56 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-03 09:43:08 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-03 09:43:41 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-03 09:43:37 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-03 09:43:38 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-03 09:43:07 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-03 09:43:07 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-03 09:41:26 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-03 09:40:56 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-03 09:40:56 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-08-03 09:43:08 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-03 09:43:37 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-03 09:40:56 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-03 09:40:56 | -1.7 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-08-03 12:04:37 | -4 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-08-03 12:02:07 | -4 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-08-03 12:44:25 | -4.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

