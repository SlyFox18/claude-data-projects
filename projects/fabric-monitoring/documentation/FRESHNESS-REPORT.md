# Data Freshness Report

**Generated:** 2026-08-14 08:01:29
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 77 | 74% |
| Stale | 2 | 1.9% |
| Critical | 12 | 11.5% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_InMaster_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:02:29 (236 hours ago)
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:05:30 (235.9 hours ago)
- **df_InMaster_PartsLookup_Raw** (RawSource) - Last refreshed: 2026-08-07 12:43:53 (163.3 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_Fact_PriceUpdate_Enriched** (FactTable) - Last refreshed: 2026-08-11 16:05:21 (63.9 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-08-12 10:02:40 (46 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-08-12 10:02:40 | 46 | [WARN] Stale |
| df_Dim_Customer | 2026-08-14 09:49:17 | -1.8 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-14 09:48:17 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-08-14 09:49:16 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-08-14 09:56:46 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-14 09:58:43 | -2 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-14 10:03:53 | -2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-14 09:58:43 | -2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-08-14 09:59:42 | -2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-14 09:58:43 | -2 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-14 09:59:12 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 63.9 | [WARN] Stale |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-13 14:19:59 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-08-14 10:07:20 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-14 10:07:51 | -2.1 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-08-14 10:07:51 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-14 10:09:50 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-14 10:08:50 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-14 10:06:50 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-14 10:14:53 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-14 10:13:31 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-14 10:14:02 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-14 10:12:32 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-14 10:12:32 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-14 10:12:01 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-14 10:17:34 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-14 10:19:49 | -2.3 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-14 10:17:04 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-14 10:19:49 | -2.3 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-14 10:17:05 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-14 10:19:50 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-08-14 10:20:19 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-14 10:19:49 | -2.3 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-14 10:17:05 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-14 10:17:38 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-08-14 10:23:19 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-08-14 10:26:03 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-08-14 10:25:33 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-14 10:25:33 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-08-14 10:25:03 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-14 10:25:33 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-08-14 10:33:17 | -2.5 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-08-14 12:32:10 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_Parts_Ordering_Raw | 2026-08-04 12:02:29 | 236 | [CRIT] Critical |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 235.9 | [CRIT] Critical |
| df_InMaster_PartsLookup_Raw | 2026-08-07 12:43:53 | 163.3 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-08-13 14:02:08 | 18 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-14 09:22:17 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-08-14 09:21:48 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-14 09:18:17 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-14 09:20:47 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-14 09:24:17 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-14 09:23:17 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-14 09:29:47 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-14 09:32:30 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-14 09:32:00 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-14 09:34:01 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-14 09:32:00 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-14 09:33:00 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-14 09:33:30 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-14 09:39:56 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-14 09:36:43 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-14 09:37:44 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-14 09:40:25 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-14 09:39:55 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-14 09:39:56 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-14 09:36:13 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-14 09:36:13 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-14 09:39:55 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-14 09:36:13 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-14 09:36:14 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-14 09:39:25 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-14 09:39:57 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-14 09:42:38 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-14 09:42:08 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-14 09:42:08 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-14 09:42:38 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-14 09:42:10 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-14 09:42:39 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-08-14 09:42:08 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-14 09:42:38 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-14 09:43:08 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

