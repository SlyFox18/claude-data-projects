# Data Freshness Report

**Generated:** 2026-06-05 08:01:41
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 78 | 78% |
| Stale |  | 0% |
| Critical | 7 | 7% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (712.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (712.6 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-20 12:54:14 (379.1 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-20 12:55:53 (379.1 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-06-01 12:33:08 (91.5 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 712.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 712.6 | [CRIT] Critical |
| df_Dim_Franchise | 2026-06-01 12:33:08 | 91.5 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-06-03 10:01:27 | 46 | [WARN] Stale |
| df_Dim_Part | 2026-06-05 09:51:51 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-06-05 09:49:21 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-06-05 09:48:51 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-05 09:53:58 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-05 09:53:58 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-05 09:53:58 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-05 09:53:57 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-05 09:54:57 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-05 09:53:59 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_JobCodeFrequency_Branch | 2026-05-20 12:55:53 | 379.1 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-20 12:54:14 | 379.1 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-06-04 14:18:28 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-06-05 09:57:20 | -1.9 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-05 10:02:21 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-05 10:00:50 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-05 10:04:19 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-05 10:02:49 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-05 10:02:50 | -2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-05 10:08:35 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-05 10:08:07 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-05 10:09:34 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-05 10:08:04 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-05 10:08:37 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-05 10:08:34 | -2.1 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-05 10:13:21 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-05 10:12:20 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-05 10:11:50 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-05 10:16:04 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-05 10:16:06 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-05 10:16:04 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-05 10:16:04 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-05 10:12:50 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-05 10:11:50 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-05 10:16:05 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-05 10:19:34 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-05 10:22:18 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-05 10:21:48 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-05 10:21:48 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-05 10:22:18 | -2.3 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-05 10:22:52 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-05 10:22:49 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-05 12:32:58 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-04 14:03:34 | 18 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-05 09:22:15 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-06-05 09:21:15 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-05 09:20:15 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-05 09:17:45 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-05 09:23:45 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-05 09:27:44 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-05 09:24:15 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-05 09:30:52 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-05 09:29:52 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-05 09:34:34 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-05 09:32:24 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-05 09:30:53 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-05 09:34:34 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-05 09:31:22 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-05 09:31:52 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-05 09:38:19 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-05 09:35:37 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-05 09:35:04 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-05 09:38:19 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-05 09:38:20 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-05 09:39:19 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-05 09:38:22 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-05 09:40:27 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-05 09:35:15 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-05 09:34:35 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-05 09:37:49 | -1.6 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-05 09:42:39 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-05 09:43:09 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-05 09:43:09 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-05 09:43:09 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-05 09:43:09 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-05 09:43:11 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-06-05 09:42:39 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-05 09:43:09 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-05 09:43:09 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-05 12:02:22 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-05 12:05:17 | -4.1 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

