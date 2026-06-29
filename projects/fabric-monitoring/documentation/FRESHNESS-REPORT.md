# Data Freshness Report

**Generated:** 2026-06-29 08:01:29
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 76 | 76% |
| Stale | 2 | 2% |
| Critical | 8 | 8% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_JobCodePartFrequency** (FactTable) - Never refreshed!
- **df_Fact_OpenOrderParts** (FactTable) - Never refreshed!
- **df_Fact_OpenOrders** (FactTable) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Never refreshed!
- **df_Dim_WkCodeFl** (Dimension) - Never refreshed!
- **df_Dim_BranchUserAccess** (Dimension) - Last refreshed: 2026-06-24 10:01:59 (118 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_ServiceTimeSheets_Raw** (RawSource) - Last refreshed: 2026-06-26 14:02:34 (66 hours ago)
- **df_Fact_ServiceTimeSheet_Audit** (FactTable) - Last refreshed: 2026-06-26 14:19:29 (65.7 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WkCodeFl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchUserAccess | 2026-06-24 10:01:59 | 118 | [CRIT] Critical |
| df_Dim_Date | 2026-06-29 09:50:09 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-06-29 09:51:09 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-29 09:55:20 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-29 09:54:50 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-29 09:54:50 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-06-29 09:53:09 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-29 09:55:20 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-29 09:54:51 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-29 09:57:51 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodePartFrequency | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_JobCodeFrequency_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_OpenOrderParts | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_ServiceTimeSheet_Audit | 2026-06-26 14:19:29 | 65.7 | [WARN] Stale |
| df_Fact_Service_Detail | 2026-06-29 10:04:14 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-06-29 10:00:14 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-29 10:05:13 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-29 10:05:44 | -2.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-29 10:06:13 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-29 10:10:03 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-29 10:04:44 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-29 10:10:03 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-29 10:15:15 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-29 10:11:06 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-29 10:14:15 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-29 10:15:46 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-29 10:15:15 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-29 10:10:35 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-29 10:11:04 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-29 10:12:03 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-29 10:14:15 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-29 10:17:57 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-29 10:21:56 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-29 10:17:57 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-29 10:17:57 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-29 10:18:27 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-29 10:17:58 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-29 10:24:40 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-29 10:25:10 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-29 10:24:41 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-29 10:24:41 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-29 10:24:10 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-29 10:24:41 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-29 12:33:32 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-26 14:02:34 | 66 | [WARN] Stale |
| df_InHist_PmManage_Raw | 2026-06-29 09:21:44 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-29 09:22:14 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-29 09:17:44 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-29 09:20:14 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-29 09:23:44 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-29 09:23:44 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-29 09:30:14 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-29 09:32:26 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-29 09:33:26 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-29 09:33:25 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-29 09:32:57 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-29 09:32:28 | -1.5 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-29 09:40:19 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-29 09:38:09 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-29 09:38:07 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-29 09:37:37 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-29 09:40:19 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-29 09:37:16 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-29 09:37:07 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-29 09:34:55 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-29 09:37:06 | -1.6 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-29 09:43:32 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-29 09:44:02 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-29 09:44:32 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-29 09:44:02 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-29 09:44:02 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-29 09:44:02 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-29 09:44:02 | -1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-29 09:40:49 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-29 09:40:49 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-06-29 09:44:02 | -1.7 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-29 09:40:49 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-29 09:40:49 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-29 09:44:03 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-29 09:41:49 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-29 12:02:08 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-29 12:05:06 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

