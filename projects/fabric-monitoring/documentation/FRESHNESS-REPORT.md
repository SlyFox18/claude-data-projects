# Data Freshness Report

**Generated:** 2026-04-14 08:01:26
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 73 | 83.9% |
| Stale | 0 | 0% |
| Critical | 12 | 13.8% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Dim_Source** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (307.5 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (307.5 hours ago)
- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-04-01 12:33:15 (307.5 hours ago)
- **df_Dim_Location** (Dimension) - Last refreshed: 2026-04-01 12:32:12 (307.5 hours ago)
- **df_Dim_PaymentMethod** (Dimension) - Last refreshed: 2026-04-01 12:36:30 (307.4 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-04-01 12:36:33 (307.4 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-04-01 12:36:29 (307.4 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-04-01 12:34:17 (307.4 hours ago)
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-04-01 12:36:59 (307.4 hours ago)
- **df_Dim_JobType** (Dimension) - Last refreshed: 2026-04-01 12:39:11 (307.4 hours ago)
- **df_Dim_AdjustmentType** (Dimension) - Last refreshed: 2026-04-01 12:35:59 (307.4 hours ago)
- **df_Dim_PromoType** (Dimension) - Last refreshed: 2026-04-01 12:43:40 (307.3 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_DealerGroupCode | 2026-04-01 12:33:15 | 307.5 | [CRIT] Critical |
| df_Dim_Location | 2026-04-01 12:32:12 | 307.5 | [CRIT] Critical |
| df_Dim_SLC | 2026-04-01 12:32:43 | 307.5 | [CRIT] Critical |
| df_Dim_Source | 2026-04-01 12:32:43 | 307.5 | [CRIT] Critical |
| df_Dim_JobType | 2026-04-01 12:39:11 | 307.4 | [CRIT] Critical |
| df_Dim_VendorCode | 2026-04-01 12:36:33 | 307.4 | [CRIT] Critical |
| df_Dim_PaymentMethod | 2026-04-01 12:36:30 | 307.4 | [CRIT] Critical |
| df_Dim_ModuleType | 2026-04-01 12:36:29 | 307.4 | [CRIT] Critical |
| df_Dim_CommodityCode | 2026-04-01 12:36:59 | 307.4 | [CRIT] Critical |
| df_Dim_Franchise | 2026-04-01 12:34:17 | 307.4 | [CRIT] Critical |
| df_Dim_AdjustmentType | 2026-04-01 12:35:59 | 307.4 | [CRIT] Critical |
| df_Dim_PromoType | 2026-04-01 12:43:40 | 307.3 | [CRIT] Critical |
| df_Dim_Customer | 2026-04-14 09:50:52 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-04-14 09:49:24 | -1.8 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-14 09:54:34 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-14 09:54:34 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-14 09:54:35 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-14 09:55:04 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-04-14 09:52:22 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-14 09:55:34 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-14 09:54:35 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-14 09:57:57 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-14 10:02:57 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-14 10:02:57 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-14 10:01:57 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-14 10:03:28 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-14 10:03:28 | -2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-14 10:08:17 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-14 10:08:18 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-14 10:08:48 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-14 10:08:16 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-14 10:07:46 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-14 10:07:45 | -2.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-14 10:11:36 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-14 10:12:37 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-14 10:11:09 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-14 10:15:20 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-14 10:15:19 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-14 10:15:19 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-14 10:12:20 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-14 10:15:50 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-14 10:15:23 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-14 10:11:05 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-14 10:19:21 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-04-14 10:22:03 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-14 10:22:04 | -2.3 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-14 10:22:05 | -2.3 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-14 10:22:05 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-14 10:22:05 | -2.3 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-14 10:22:35 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | Error | 0 | [?] Error |
| df_Parts_InterbranchTransfer_Raw | 2026-04-14 09:17:45 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-14 09:20:45 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-04-14 09:20:45 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-14 09:21:45 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-14 09:24:15 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-14 09:28:17 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-14 09:24:15 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-14 09:31:00 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-14 09:32:29 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-14 09:32:00 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-14 09:30:29 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-14 09:31:29 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-14 09:31:30 | -1.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-14 09:39:09 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-14 09:35:41 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-14 09:36:16 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-14 09:40:09 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-14 09:39:11 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-14 09:39:09 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-14 09:34:42 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-14 09:34:41 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-14 09:38:39 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-14 09:34:41 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-14 09:34:41 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-14 09:38:39 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-14 09:39:11 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-14 09:42:57 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-14 09:42:27 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-14 09:42:57 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-14 09:42:57 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-14 09:43:43 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-14 09:42:27 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-04-14 09:42:57 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-14 09:42:59 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-14 09:42:27 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

