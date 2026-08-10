# Data Freshness Report

**Generated:** 2026-08-10 08:01:36
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 67 | 65.7% |
| Stale | 3 | 2.9% |
| Critical | 18 | 17.6% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_Planter_Inspection_Part_Sales** (FactTable) - Last refreshed: 2026-08-04 10:13:34 (141.8 hours ago)
- **df_Fact_Top50_JobCodes** (FactTable) - Last refreshed: 2026-08-04 10:14:04 (141.8 hours ago)
- **df_Fact_NegativeOnHand_OnHandNoBin** (FactTable) - Last refreshed: 2026-08-04 10:13:04 (141.8 hours ago)
- **df_Fact_AdjustmentPairs** (FactTable) - Last refreshed: 2026-08-04 10:13:04 (141.8 hours ago)
- **df_Fact_InSalOrd_InSalPar** (FactTable) - Last refreshed: 2026-08-04 10:13:36 (141.8 hours ago)
- **df_Fact_PartsPromo** (FactTable) - Last refreshed: 2026-08-04 10:13:03 (141.8 hours ago)
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:02:29 (140 hours ago)
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:05:30 (139.9 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-08-05 10:04:14 (118 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_InMaster_PartsLookup_Raw** (RawSource) - Last refreshed: 2026-08-07 12:43:53 (67.3 hours ago)
- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-08-07 14:02:10 (66 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-08-07 14:19:35 (65.7 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-08-05 10:04:14 | 118 | [CRIT] Critical |
| df_Dim_Date | 2026-08-10 09:50:50 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-08-10 09:51:20 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-10 09:50:21 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-10 09:54:02 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-10 09:54:02 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-10 09:54:03 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-08-10 09:52:21 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-10 09:54:32 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-10 09:54:03 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-08-10 09:56:02 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Top50_JobCodes | 2026-08-04 10:14:04 | 141.8 | [CRIT] Critical |
| df_Fact_PartsPromo | 2026-08-04 10:13:03 | 141.8 | [CRIT] Critical |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-04 10:13:04 | 141.8 | [CRIT] Critical |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-04 10:13:34 | 141.8 | [CRIT] Critical |
| df_Fact_AdjustmentPairs | 2026-08-04 10:13:04 | 141.8 | [CRIT] Critical |
| df_Fact_InSalOrd_InSalPar | 2026-08-04 10:13:36 | 141.8 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-07 14:19:35 | 65.7 | [WARN] Stale |
| df_Fact_Transfers | Error | 0 | [?] Error |
| df_Fact_InTrans_UniqueCustomers | Error | 0 | [?] Error |
| df_Fact_InternalWorkOrders | 2026-08-10 12:32:40 | -4.5 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-10 12:44:35 | -4.7 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-08-10 12:43:05 | -4.7 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-10 12:42:04 | -4.7 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-10 12:42:05 | -4.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-08-10 12:41:04 | -4.7 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-10 12:50:05 | -4.8 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-10 12:52:47 | -4.9 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-10 12:56:57 | -4.9 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-10 12:56:29 | -4.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-10 12:54:17 | -4.9 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-10 12:53:17 | -4.9 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-10 12:56:27 | -4.9 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-10 12:52:47 | -4.9 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-10 12:54:16 | -4.9 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-10 12:53:46 | -4.9 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-10 12:56:58 | -4.9 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-10 12:56:58 | -4.9 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-10 12:59:12 | -5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-10 12:59:42 | -5 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-10 12:59:12 | -5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-10 12:59:12 | -5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_Parts_Ordering_Raw | 2026-08-04 12:02:29 | 140 | [CRIT] Critical |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 139.9 | [CRIT] Critical |
| df_InMaster_PartsLookup_Raw | 2026-08-07 12:43:53 | 67.3 | [WARN] Stale |
| df_ServiceTimeSheets_Raw | 2026-08-07 14:02:10 | 66 | [WARN] Stale |
| df_InHist_PmManage_Raw | 2026-08-10 09:22:24 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-10 09:18:24 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-10 09:20:54 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-10 09:24:24 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-10 09:23:54 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-10 09:22:54 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-10 09:34:07 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-10 09:34:08 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-10 09:31:54 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-10 09:38:18 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-10 09:39:18 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-10 09:39:48 | -1.6 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-10 09:34:37 | -1.6 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-10 09:34:37 | -1.6 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-10 09:35:06 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-10 09:38:18 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-10 09:38:19 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-10 09:36:07 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-10 09:38:18 | -1.6 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-10 09:44:44 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-10 09:44:44 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-10 09:42:31 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-10 09:42:01 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-10 09:44:44 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-10 09:44:44 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-10 09:44:44 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-10 09:42:02 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-10 09:42:01 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-10 09:44:54 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-08-10 09:44:44 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-10 09:42:01 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-10 09:42:31 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-10 09:42:32 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-10 09:44:44 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-10 09:44:44 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

