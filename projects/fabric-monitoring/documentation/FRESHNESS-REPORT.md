# Data Freshness Report

**Generated:** 2026-05-28 08:01:31
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 77 | 79.4% |
| Stale |  | 0% |
| Critical | 8 | 8.2% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (520.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (520.6 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-20 12:50:41 (187.2 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-20 12:50:38 (187.2 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-20 12:54:14 (187.1 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-20 12:55:53 (187.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 520.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 520.6 | [CRIT] Critical |
| df_Dim_Franchise | 2026-05-26 16:21:38 | 39.7 | [WARN] Stale |
| df_Dim_BranchUserAccess | 2026-05-27 10:02:03 | 22 | [OK] Fresh |
| df_Dim_Date | 2026-05-28 10:09:06 | -2.1 | [OK] Fresh |
| df_Dim_Customer | 2026-05-28 10:10:02 | -2.1 | [OK] Fresh |
| df_Dim_Technicans | 2026-05-28 10:13:52 | -2.2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-05-28 10:13:47 | -2.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-05-28 10:13:46 | -2.2 | [OK] Fresh |
| df_Dim_Part | 2026-05-28 10:12:03 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-05-28 10:15:17 | -2.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-05-28 10:14:18 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-05-28 10:19:30 | -2.3 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-20 12:50:41 | 187.2 | [CRIT] Critical |
| df_Fact_OpenOrderParts | 2026-05-20 12:50:38 | 187.2 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-20 12:54:14 | 187.1 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-20 12:55:53 | 187.1 | [CRIT] Critical |
| df_FactPartTransactions_Incremental | 2026-05-28 10:22:00 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-05-28 10:27:30 | -2.4 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-05-28 10:25:32 | -2.4 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-05-28 10:28:00 | -2.4 | [OK] Fresh |
| df_Fact_Inventory | 2026-05-28 10:26:30 | -2.4 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-05-28 10:27:00 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-05-28 10:31:43 | -2.5 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-05-28 10:31:43 | -2.5 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-05-28 10:32:43 | -2.5 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-05-28 10:32:13 | -2.5 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-05-28 10:32:43 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-05-28 10:32:13 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-05-28 10:35:27 | -2.6 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-05-28 10:35:28 | -2.6 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-05-28 10:34:58 | -2.6 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-05-28 10:34:59 | -2.6 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-05-28 10:43:21 | -2.7 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-05-28 10:43:52 | -2.7 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-05-28 10:43:51 | -2.7 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-05-28 10:43:52 | -2.7 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-05-28 10:41:07 | -2.7 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-05-28 10:43:52 | -2.7 | [OK] Fresh |
| df_Fact_Transfers | 2026-05-28 10:47:51 | -2.8 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-05-28 10:50:39 | -2.8 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-05-28 10:51:08 | -2.8 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-05-28 10:50:41 | -2.8 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-05-28 10:50:11 | -2.8 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-05-28 10:50:40 | -2.8 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-05-28 10:50:39 | -2.8 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-05-28 12:33:31 | -4.5 | [OK] Fresh |
| df_Fact_ServiceTimeSheet_Audit | 2026-05-28 12:45:01 | -4.7 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-05-27 14:03:03 | 18 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-05-28 09:17:44 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-05-28 09:22:15 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-05-28 09:20:14 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-05-28 09:25:21 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-05-28 09:23:44 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-05-28 09:26:14 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-05-28 09:43:32 | -1.7 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-05-28 09:46:15 | -1.7 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-05-28 09:45:45 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-05-28 09:45:46 | -1.7 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-05-28 09:48:52 | -1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-05-28 09:51:04 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-05-28 09:51:06 | -1.8 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-05-28 09:46:46 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-05-28 09:51:05 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-05-28 09:47:46 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-05-28 09:51:06 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-05-28 09:56:17 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-05-28 09:52:35 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-05-28 09:55:17 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-05-28 09:55:17 | -1.9 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-05-28 09:52:35 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-05-28 09:54:47 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-05-28 09:55:17 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-05-28 09:55:18 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-05-28 09:55:17 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-05-28 10:01:01 | -2 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-05-28 09:58:33 | -2 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-05-28 10:00:31 | -2 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-05-28 09:58:32 | -2 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-05-28 09:58:31 | -2 | [OK] Fresh |
| df_WarClaim_Raw | 2026-05-28 09:59:32 | -2 | [OK] Fresh |
| df_Technician_Raw | 2026-05-28 09:58:31 | -2 | [OK] Fresh |
| df_CONTACT_Raw | 2026-05-28 09:59:01 | -2 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-05-28 09:58:31 | -2 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

