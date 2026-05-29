# Data Freshness Report

**Generated:** 2026-05-29 08:01:24
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 76 | 78.4% |
| Stale | 2 | 2.1% |
| Critical | 8 | 8.2% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (544.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (544.6 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-20 12:50:41 (211.2 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-20 12:50:38 (211.2 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-20 12:54:14 (211.1 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-20 12:55:53 (211.1 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-05-26 16:21:38 (63.7 hours ago)
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-05-27 10:02:03 (46 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 544.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 544.6 | [CRIT] Critical |
| df_Dim_Franchise | 2026-05-26 16:21:38 | 63.7 | [WARN] Stale |
| df_Dim_BranchUserAccess | 2026-05-27 10:02:03 | 46 | [WARN] Stale |
| df_Dim_Date | 2026-05-29 09:50:53 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-29 09:56:04 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-29 09:56:02 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-29 09:56:01 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-29 09:56:01 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-29 09:56:32 | -1.9 | [OK] Fresh |
| df_Dim_Customer | 2026-05-29 09:52:11 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-29 09:57:01 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-05-29 09:53:50 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-20 12:50:41 | 211.2 | [CRIT] Critical |
| df_Fact_OpenOrderParts | 2026-05-20 12:50:38 | 211.2 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-20 12:54:14 | 211.1 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-20 12:55:53 | 211.1 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-05-28 16:49:03 | 15.2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-05-29 09:59:28 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-29 10:02:59 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-29 10:04:29 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-29 10:04:59 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-29 10:04:31 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-29 10:07:24 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-29 10:11:29 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-29 10:15:15 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-29 10:11:30 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-29 10:12:31 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-29 10:12:33 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-29 10:12:29 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-29 10:17:34 | -2.3 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-29 10:19:05 | -2.3 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-29 10:17:34 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-29 10:22:11 | -2.3 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-29 10:18:04 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-29 10:24:24 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-29 10:24:55 | -2.4 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-29 10:24:55 | -2.4 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-29 10:24:53 | -2.4 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-29 10:24:54 | -2.4 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-29 10:31:37 | -2.5 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-29 10:32:07 | -2.5 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-29 10:28:53 | -2.5 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-29 10:31:06 | -2.5 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-29 10:31:37 | -2.5 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-29 10:31:07 | -2.5 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-29 10:31:38 | -2.5 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-05-29 12:33:01 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-05-28 14:02:04 | 18 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-29 09:20:16 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-29 09:21:44 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-29 09:17:44 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-29 09:21:44 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-29 09:23:44 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-29 09:27:14 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-29 09:23:44 | -1.4 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-29 09:29:56 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-29 09:34:03 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-29 09:29:56 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-29 09:29:27 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-29 09:29:25 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-29 09:29:56 | -1.5 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-29 09:33:38 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-29 09:31:25 | -1.5 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-29 09:33:09 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-29 09:33:38 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-29 09:39:52 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-29 09:34:39 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-29 09:38:51 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-29 09:38:50 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-29 09:36:03 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-29 09:38:20 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-29 09:38:51 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-29 09:38:51 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-29 09:38:51 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-29 09:42:04 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-29 09:45:04 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-29 09:42:06 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-29 09:42:04 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-05-29 09:42:04 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-29 09:43:04 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-29 09:42:07 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-29 09:42:04 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-29 09:42:35 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

