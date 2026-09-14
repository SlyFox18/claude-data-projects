# Data Freshness Report

**Generated:** 2026-09-14 08:01:27
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 76 | 73.1% |
| Stale | 2 | 1.9% |
| Critical | 10 | 9.6% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_GlMaster_Raw** (RawSource) - Last refreshed: 2026-08-24 13:57:10 (498.1 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-09-09 10:05:56 (117.9 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-09-11 14:02:50 (66 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-09-11 14:18:46 (65.7 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-09-09 10:05:56 | 117.9 | [CRIT] Critical |
| df_Dim_Date | 2026-09-14 09:37:24 | -1.6 | [OK] Fresh |
| df_Dim_Customer | 2026-09-14 09:37:54 | -1.6 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-09-14 09:37:24 | -1.6 | [OK] Fresh |
| df_Dim_Technicans | 2026-09-14 09:43:35 | -1.7 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-09-14 09:43:35 | -1.7 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-09-14 09:43:05 | -1.7 | [OK] Fresh |
| df_Dim_Salesperson | 2026-09-14 09:43:04 | -1.7 | [OK] Fresh |
| df_Dim_JobCode | 2026-09-14 09:43:34 | -1.7 | [OK] Fresh |
| df_Dim_Part | 2026-09-14 09:41:25 | -1.7 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-09-14 09:44:04 | -1.7 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-09-11 14:18:46 | 65.7 | [WARN] Stale |
| df_FactPartTransactions_Incremental | 2026-09-14 09:46:12 | -1.7 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-09-14 09:50:40 | -1.8 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-09-14 09:46:42 | -1.8 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-09-14 09:46:42 | -1.8 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-09-14 09:50:13 | -1.8 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-09-14 09:47:45 | -1.8 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-09-14 09:50:11 | -1.8 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-09-14 09:50:10 | -1.8 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-09-14 09:49:41 | -1.8 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-09-14 09:46:43 | -1.8 | [OK] Fresh |
| df_Fact_Inventory | 2026-09-14 09:46:42 | -1.8 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-09-14 09:50:14 | -1.8 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-09-14 09:52:06 | -1.8 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-09-14 09:57:59 | -1.9 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-09-14 09:55:01 | -1.9 | [OK] Fresh |
| df_Fact_Transfers | 2026-09-14 09:56:01 | -1.9 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-09-14 09:57:59 | -1.9 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-09-14 09:52:36 | -1.9 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-09-14 09:55:01 | -1.9 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-09-14 09:55:31 | -1.9 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-09-14 09:53:06 | -1.9 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-09-14 09:57:29 | -1.9 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-09-14 09:57:29 | -1.9 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-09-14 09:52:36 | -1.9 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-09-14 09:55:01 | -1.9 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-09-14 09:55:01 | -1.9 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-09-14 09:52:36 | -1.9 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-09-14 09:58:28 | -2 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-09-14 09:58:29 | -2 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-09-14 12:32:17 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_NonJD_Parts_Ordering_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | 2026-08-24 13:57:10 | 498.1 | [CRIT] Critical |
| df_ServiceTimeSheets_Raw | 2026-09-11 14:02:50 | 66 | [WARN] Stale |
| df_InTrans_PartsCounter_Raw | 2026-09-14 09:19:28 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-09-14 09:18:58 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-09-14 09:19:28 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-09-14 09:17:28 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-09-14 09:20:58 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-09-14 09:18:28 | -1.3 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-09-14 09:25:41 | -1.4 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-09-14 09:25:44 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-09-14 09:25:11 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-09-14 09:25:13 | -1.4 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-09-14 09:27:13 | -1.4 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-09-14 09:27:39 | -1.4 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-09-14 09:27:39 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-09-14 09:25:10 | -1.4 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-09-14 09:28:09 | -1.4 | [OK] Fresh |
| df_INSALORD_Raw | 2026-09-14 09:27:39 | -1.4 | [OK] Fresh |
| df_InMaster_Raw | 2026-09-14 09:25:40 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-09-14 09:22:58 | -1.4 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-09-14 09:27:39 | -1.4 | [OK] Fresh |
| df_WarClaim_Raw | 2026-09-14 09:32:06 | -1.5 | [OK] Fresh |
| df_VhTrans_Raw | 2026-09-14 09:30:05 | -1.5 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-09-14 09:32:07 | -1.5 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-09-14 09:32:08 | -1.5 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-09-14 09:32:06 | -1.5 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-09-14 09:31:37 | -1.5 | [OK] Fresh |
| df_CONTACT_Raw | 2026-09-14 09:32:06 | -1.5 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-09-14 09:31:37 | -1.5 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-09-14 09:29:35 | -1.5 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-09-14 09:30:07 | -1.5 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-09-14 09:30:06 | -1.5 | [OK] Fresh |
| df_Technician_Raw | 2026-09-14 09:31:36 | -1.5 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-09-14 09:32:06 | -1.5 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-09-14 09:30:05 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-09-14 09:30:05 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-09-14 09:30:05 | -1.5 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-09-14 12:52:09 | -4.8 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

