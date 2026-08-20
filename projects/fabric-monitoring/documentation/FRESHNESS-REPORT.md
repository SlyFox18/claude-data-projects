# Data Freshness Report

**Generated:** 2026-08-20 08:01:34
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 79 | 76% |
| Stale |  | 0% |
| Critical | 10 | 9.6% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_PartDemands** (Dimension) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_NonJD_Parts_Ordering_Raw** (RawSource) - Last refreshed: 2026-08-04 12:05:30 (379.9 hours ago)
- **df_Fact_PriceUpdate_Enriched** (FactTable) - Last refreshed: 2026-08-11 16:05:21 (207.9 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_PartDemands | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-08-19 10:02:09 | 22 | [OK] Fresh |
| df_Dim_Date | 2026-08-20 09:53:18 | -1.9 | [OK] Fresh |
| df_Dim_Customer | 2026-08-20 09:54:48 | -1.9 | [OK] Fresh |
| df_Dim_BranchPartInventory | 2026-08-20 09:52:48 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-08-20 10:01:00 | -2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-08-20 10:00:59 | -2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-08-20 10:01:30 | -2 | [OK] Fresh |
| df_Dim_Part | 2026-08-20 09:59:19 | -2 | [OK] Fresh |
| df_Dim_JobCode | 2026-08-20 10:01:29 | -2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-08-20 10:01:29 | -2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-08-20 10:02:00 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PriceUpdate_Enriched | 2026-08-11 16:05:21 | 207.9 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-08-19 14:20:06 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-08-20 10:05:49 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-08-20 10:05:37 | -2.1 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-08-20 10:06:11 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-08-20 10:08:07 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-08-20 10:06:15 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-08-20 10:06:07 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-08-20 10:11:50 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-08-20 10:12:18 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-08-20 10:10:49 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-08-20 10:11:18 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-08-20 10:10:50 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-08-20 10:20:02 | -2.3 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-08-20 10:17:22 | -2.3 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-08-20 10:19:33 | -2.3 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-08-20 10:20:32 | -2.3 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-08-20 10:19:34 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-08-20 10:20:31 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-08-20 10:22:43 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-08-20 10:27:57 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-08-20 10:22:44 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-08-20 10:22:43 | -2.4 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-08-20 10:23:13 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-08-20 10:27:56 | -2.4 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-08-20 10:22:44 | -2.4 | [OK] Fresh |
| df_Fact_Transfers | 2026-08-20 10:26:13 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-08-20 10:28:57 | -2.5 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-08-20 10:28:26 | -2.5 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-08-20 10:28:27 | -2.5 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-08-20 10:28:27 | -2.5 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-08-20 12:32:30 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_NonJD_Parts_Ordering_Raw | 2026-08-04 12:05:30 | 379.9 | [CRIT] Critical |
| df_InMaster_Parts_Ordering_Raw | 2026-08-17 19:46:00 | 60.3 | [WARN] Stale |
| df_ServiceTimeSheets_Raw | 2026-08-19 14:03:49 | 18 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-08-20 09:22:21 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-08-20 09:18:20 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-08-20 09:25:21 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-08-20 09:22:51 | -1.4 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-08-20 09:25:35 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-08-20 09:23:51 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-08-20 09:33:55 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-08-20 09:36:37 | -1.6 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-08-20 09:37:07 | -1.6 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-08-20 09:36:08 | -1.6 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-08-20 09:36:37 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-08-20 09:40:18 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-08-20 09:40:18 | -1.6 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-08-20 09:36:07 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-08-20 09:38:07 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-08-20 09:40:18 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-08-20 09:44:04 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-08-20 09:44:34 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-08-20 09:41:49 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-08-20 09:44:04 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-08-20 09:46:17 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-08-20 09:46:16 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-08-20 09:46:16 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-08-20 09:44:04 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-08-20 09:44:04 | -1.7 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-08-20 09:41:48 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-08-20 09:44:03 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-08-20 09:44:04 | -1.7 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-08-20 09:41:48 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-08-20 09:46:46 | -1.8 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-08-20 09:46:46 | -1.8 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-08-20 09:46:46 | -1.8 | [OK] Fresh |
| df_Technician_Raw | 2026-08-20 09:46:46 | -1.8 | [OK] Fresh |
| df_CONTACT_Raw | 2026-08-20 09:46:46 | -1.8 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-08-20 09:46:46 | -1.8 | [OK] Fresh |
| df_InMaster_PartsLookup_Raw | 2026-08-20 12:53:27 | -4.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

