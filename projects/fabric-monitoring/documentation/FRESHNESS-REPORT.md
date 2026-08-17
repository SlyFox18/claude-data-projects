# Data Freshness Report

**Generated:** 2026-08-17 08:01:30
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 75 | 72.1% |
| Stale | 3 | 2.9% |
| Critical | 13 | 12.5% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:02:29 (308 hours ago)
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:05:30 (307.9 hours ago)
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Last refreshed: 2026-08-11 16:05:21 (135.9 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-08-12 10:02:40 (118 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_InMaster_PartsLookup_Raw** (RawSource) - Last refreshed: 2026-08-14 13:21:25 (66.7 hours ago)
- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-08-14 14:03:17 (66 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-08-14 14:20:00 (65.7 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-08-12 10:02:40 | 118 | [CRIT] Critical |
| df_Dim_Customer | 2026-08-17 09:56:32 | -1.9 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-17 09:54:31 | -1.9 | [OK] Fresh |
| df_Dim_Date | 2026-08-17 09:55:02 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-08-17 10:02:01 | -2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-17 10:06:26 | -2.1 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-17 10:04:26 | -2.1 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-17 10:04:23 | -2.1 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-08-17 10:05:25 | -2.1 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-17 10:05:53 | -2.1 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-17 10:04:30 | -2.1 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 135.9 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-14 14:20:00 | 65.7 | [WARN] Stale |
| df_Fact_Service_Invoices | 2026-08-17 10:09:54 | -2.1 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-08-17 10:08:54 | -2.1 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-08-17 10:10:57 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-17 10:12:25 | -2.2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-17 10:11:26 | -2.2 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-17 10:14:32 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-17 10:20:57 | -2.3 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-17 10:20:56 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-17 10:18:44 | -2.3 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-17 10:21:26 | -2.3 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-17 10:17:14 | -2.3 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-17 10:17:14 | -2.3 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-17 10:21:26 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-17 10:17:44 | -2.3 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-17 10:17:43 | -2.3 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-17 10:18:45 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-17 10:21:27 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-17 10:23:39 | -2.4 | [OK] Fresh |
| df_Fact_Transfers | 2026-08-17 10:27:09 | -2.4 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-08-17 10:24:09 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-17 10:23:38 | -2.4 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-17 10:23:38 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-17 10:24:09 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-08-17 10:29:22 | -2.5 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-17 10:29:21 | -2.5 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-08-17 10:29:22 | -2.5 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-08-17 10:30:22 | -2.5 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-08-17 10:29:22 | -2.5 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-17 10:29:21 | -2.5 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-08-17 12:33:28 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_Parts_Ordering_Raw | 2026-08-04 12:02:29 | 308 | [CRIT] Critical |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 307.9 | [CRIT] Critical |
| df_InMaster_PartsLookup_Raw | 2026-08-14 13:21:25 | 66.7 | [WARN] Stale |
| df_ServiceTimeSheets_Raw | 2026-08-14 14:03:17 | 66 | [WARN] Stale |
| df_GlTrans_Raw | 2026-08-17 09:22:23 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-08-17 09:22:23 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-17 09:20:53 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-17 09:18:23 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-17 09:24:53 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-17 09:23:24 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-17 09:33:39 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-17 09:34:09 | -1.5 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-17 09:31:24 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-17 09:38:47 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-17 09:35:39 | -1.6 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-17 09:34:39 | -1.6 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-17 09:34:39 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-17 09:42:29 | -1.7 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-17 09:43:30 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-17 09:45:46 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-17 09:46:15 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-17 09:46:15 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-17 09:46:15 | -1.7 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-17 09:40:59 | -1.7 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-17 09:40:58 | -1.7 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-17 09:43:34 | -1.7 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-17 09:40:59 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-17 09:46:15 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-17 09:45:46 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-17 09:45:45 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-17 09:49:13 | -1.8 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-17 09:49:02 | -1.8 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-17 09:49:03 | -1.8 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-17 09:48:32 | -1.8 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-17 09:48:32 | -1.8 | [OK] Fresh |
| df_Technician_Raw | 2026-08-17 09:48:33 | -1.8 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-17 09:48:32 | -1.8 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-17 09:49:02 | -1.8 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-17 09:48:33 | -1.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

