# Data Freshness Report

**Generated:** 2026-06-02 08:01:35
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 80 | 80.8% |
| Stale | 0 | 0% |
| Critical | 8 | 8.1% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_GlMaster_Raw** (RawSource) - Never refreshed!
- **df_GlTrans_Full_Raw** (RawSource) - Never refreshed!
- **df_Dim_WKCDPART** (Dimension) - Last refreshed: 2026-05-06 15:04:38 (640.9 hours ago)
- **df_Dim_WkCodeFl** (Dimension) - Last refreshed: 2026-05-06 15:26:40 (640.6 hours ago)
- **df_Fact_OpenOrders** (FactTable) - Last refreshed: 2026-05-20 12:50:41 (307.2 hours ago)
- **df_Fact_OpenOrderParts** (FactTable) - Last refreshed: 2026-05-20 12:50:38 (307.2 hours ago)
- **df_Fact_JobCodePartFrequency** (FactTable) - Last refreshed: 2026-05-20 12:54:14 (307.1 hours ago)
- **df_Fact_JobCodeFrequency_Branch** (FactTable) - Last refreshed: 2026-05-20 12:55:53 (307.1 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_WKCDPART | 2026-05-06 15:04:38 | 640.9 | [CRIT] Critical |
| df_Dim_WkCodeFl | 2026-05-06 15:26:40 | 640.6 | [CRIT] Critical |
| df_Dim_Franchise | 2026-06-01 12:33:08 | 19.5 | [OK] Fresh |
| df_Dim_Part | 2026-06-02 09:51:18 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-06-02 09:49:18 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-06-02 09:48:18 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-06-02 09:53:29 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-06-02 09:53:29 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-06-02 09:53:29 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-06-02 09:54:29 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-06-02 09:54:28 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-06-02 09:52:58 | -1.9 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-06-02 10:01:32 | -2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_OpenOrders | 2026-05-20 12:50:41 | 307.2 | [CRIT] Critical |
| df_Fact_OpenOrderParts | 2026-05-20 12:50:38 | 307.2 | [CRIT] Critical |
| df_Fact_JobCodePartFrequency | 2026-05-20 12:54:14 | 307.1 | [CRIT] Critical |
| df_Fact_JobCodeFrequency_Branch | 2026-05-20 12:55:53 | 307.1 | [CRIT] Critical |
| df_Fact_ServiceTimeSheet_Audit | 2026-06-01 14:17:59 | 17.7 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-06-02 09:56:51 | -1.9 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-06-02 10:02:51 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-06-02 10:02:21 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-06-02 10:01:51 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-06-02 10:00:21 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-06-02 10:02:21 | -2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-06-02 10:07:36 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-06-02 10:09:48 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-06-02 10:06:41 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-06-02 10:07:06 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-06-02 10:07:39 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-06-02 10:07:17 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-06-02 10:12:38 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-06-02 10:13:06 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-06-02 10:13:06 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-06-02 10:12:08 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-06-02 10:16:18 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-06-02 10:15:48 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-06-02 10:15:48 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-06-02 10:12:06 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-06-02 10:15:48 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-06-02 10:19:48 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-06-02 10:22:03 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-06-02 10:16:22 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-06-02 10:21:32 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-06-02 10:22:02 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-06-02 10:25:42 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-06-02 10:26:11 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-06-02 10:25:11 | -2.4 | [OK] Fresh |
| df_Fact_InternalWorkOrders | 2026-06-02 12:33:00 | -4.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlMaster_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_GlTrans_Full_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_ServiceTimeSheets_Raw | 2026-06-01 14:02:58 | 18 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-06-02 09:21:48 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-06-02 09:17:48 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-06-02 09:21:53 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-06-02 09:23:18 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-06-02 09:28:18 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-06-02 09:24:18 | -1.4 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-06-02 09:25:55 | -1.4 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-06-02 09:31:00 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-06-02 09:30:30 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-06-02 09:31:30 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-06-02 09:31:31 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-06-02 09:30:30 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-06-02 09:32:31 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-06-02 09:36:11 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-06-02 09:36:11 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-06-02 09:38:54 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-06-02 09:38:54 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-06-02 09:34:41 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-06-02 09:38:54 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-06-02 09:38:54 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-06-02 09:39:53 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-06-02 09:34:41 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-06-02 09:38:24 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-06-02 09:34:41 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-06-02 09:34:42 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-06-02 09:38:24 | -1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-06-02 09:42:35 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-06-02 09:42:35 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-06-02 09:42:36 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-06-02 09:42:36 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-06-02 09:42:35 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-06-02 09:42:36 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-06-02 09:42:36 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-06-02 09:42:36 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-06-02 09:42:36 | -1.7 | [OK] Fresh |
| df_InMaster_Parts_Ordering_Raw | 2026-06-02 12:02:46 | -4 | [OK] Fresh |
| df_NonJD_Parts_Ordering_Raw | 2026-06-02 12:12:27 | -4.2 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

