# Data Freshness Report

**Generated:** 2026-06-22 08:01:34
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 76 | 76% |
| Stale | 2 | 2% |
| Critical | 10 | 10% |

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
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-06-01 12:33:08 (499.5 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-06-17 10:01:48 (118 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-06-19 14:01:59 (66 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-06-19 21:49:17 (58.2 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Franchise | 2026-06-01 12:33:08 | 499.5 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-06-17 10:01:48 | 118 | [CRIT] Critical |
| df_Dim_Part | 2026-06-22 10:08:38 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-06-22 10:06:06 | -2.1 | [OK] Fresh |
| df_Dim_Date | 2026-06-22 10:05:38 | -2.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-22 10:10:51 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-22 10:10:52 | -2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-22 10:10:53 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-22 10:10:51 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-22 10:11:22 | -2.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-22 10:10:57 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-06-19 21:49:17 | 58.2 | [WARN] Stale |
| df_FactPartTransactions_Incremental | 2026-06-22 10:13:49 | -2.2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-22 10:18:47 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-22 10:18:49 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-22 10:17:49 | -2.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-22 10:17:18 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-22 10:19:17 | -2.3 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-22 10:24:06 | -2.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-22 10:23:06 | -2.4 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-22 10:26:18 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-22 10:23:06 | -2.4 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-22 10:27:18 | -2.4 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-22 10:26:49 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-22 10:23:40 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-22 10:23:38 | -2.4 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-22 10:26:47 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-22 10:23:36 | -2.4 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-22 10:32:00 | -2.5 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-22 10:29:27 | -2.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-22 10:32:29 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-22 10:32:29 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-22 10:32:30 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-22 10:32:31 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-22 10:36:01 | -2.6 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-22 10:39:45 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-22 10:38:14 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-22 10:39:14 | -2.6 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-22 10:39:29 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-22 10:39:14 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-22 10:39:16 | -2.6 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-22 12:33:01 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-19 14:01:59 | 66 | [WARN] Stale |
| df_GlTrans_Raw | 2026-06-22 09:21:43 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-22 09:17:43 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-06-22 09:21:48 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-22 09:20:43 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-22 09:23:13 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-22 09:23:43 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-22 09:46:32 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-22 09:46:01 | -1.7 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-22 09:43:48 | -1.7 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-22 09:46:31 | -1.7 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-22 09:46:02 | -1.7 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-22 09:51:43 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-22 09:50:11 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-22 09:51:11 | -1.8 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-22 09:47:01 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-22 09:50:12 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-22 09:48:01 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-22 09:50:42 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-22 09:50:12 | -1.8 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-22 09:57:41 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-22 09:53:55 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-22 09:54:25 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-22 09:58:10 | -1.9 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-22 09:58:09 | -1.9 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-22 09:58:09 | -1.9 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-22 09:57:40 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-22 09:57:40 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-06-22 09:58:10 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-22 09:53:55 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-22 09:53:57 | -1.9 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-22 09:58:10 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-22 09:55:25 | -1.9 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-22 09:58:10 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-22 09:54:25 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-22 09:54:25 | -1.9 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-22 12:02:03 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-22 12:04:33 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

