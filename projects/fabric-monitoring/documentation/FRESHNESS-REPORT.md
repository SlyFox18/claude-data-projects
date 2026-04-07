# Data Freshness Report

**Generated:** 2026-04-07 08:01:25
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 72 | 85.7% |
| Stale | 0 | 0% |
| Critical | 12 | 14.3% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Dim_Source** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (139.5 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (139.5 hours ago)
- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-04-01 12:33:15 (139.5 hours ago)
- **df_Dim_Location** (Dimension) - Last refreshed: 2026-04-01 12:32:12 (139.5 hours ago)
- **df_Dim_PaymentMethod** (Dimension) - Last refreshed: 2026-04-01 12:36:30 (139.4 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-04-01 12:36:33 (139.4 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-04-01 12:36:29 (139.4 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-04-01 12:34:17 (139.4 hours ago)
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-04-01 12:36:59 (139.4 hours ago)
- **df_Dim_JobType** (Dimension) - Last refreshed: 2026-04-01 12:39:11 (139.4 hours ago)
- **df_Dim_AdjustmentType** (Dimension) - Last refreshed: 2026-04-01 12:35:59 (139.4 hours ago)
- **df_Dim_PromoType** (Dimension) - Last refreshed: 2026-04-01 12:43:40 (139.3 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_DealerGroupCode | 2026-04-01 12:33:15 | 139.5 | [CRIT] Critical |
| df_Dim_Location | 2026-04-01 12:32:12 | 139.5 | [CRIT] Critical |
| df_Dim_SLC | 2026-04-01 12:32:43 | 139.5 | [CRIT] Critical |
| df_Dim_Source | 2026-04-01 12:32:43 | 139.5 | [CRIT] Critical |
| df_Dim_JobType | 2026-04-01 12:39:11 | 139.4 | [CRIT] Critical |
| df_Dim_VendorCode | 2026-04-01 12:36:33 | 139.4 | [CRIT] Critical |
| df_Dim_PaymentMethod | 2026-04-01 12:36:30 | 139.4 | [CRIT] Critical |
| df_Dim_ModuleType | 2026-04-01 12:36:29 | 139.4 | [CRIT] Critical |
| df_Dim_CommodityCode | 2026-04-01 12:36:59 | 139.4 | [CRIT] Critical |
| df_Dim_Franchise | 2026-04-01 12:34:17 | 139.4 | [CRIT] Critical |
| df_Dim_AdjustmentType | 2026-04-01 12:35:59 | 139.4 | [CRIT] Critical |
| df_Dim_PromoType | 2026-04-01 12:43:40 | 139.3 | [CRIT] Critical |
| df_Dim_Customer | 2026-04-07 09:50:26 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-04-07 09:49:26 | -1.8 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-07 09:55:37 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-07 09:55:06 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-07 09:55:06 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-07 09:55:06 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-04-07 09:52:56 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-07 09:56:06 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-07 09:55:06 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-07 09:58:30 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-07 10:02:58 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-07 10:03:58 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-07 10:02:01 | -2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-07 10:03:28 | -2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-07 10:09:49 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-07 10:06:00 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-07 10:09:52 | -2.1 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-07 10:14:36 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-07 10:11:52 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-07 10:15:38 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-07 10:14:35 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-07 10:15:05 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-07 10:10:47 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-07 10:14:38 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-07 10:11:03 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-07 10:10:48 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-07 10:18:27 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-07 10:17:57 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-07 10:18:26 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-07 10:18:26 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-07 10:18:28 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-07 10:24:45 | -2.4 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-07 10:22:27 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-07 10:25:44 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-07 10:24:43 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-07 10:24:46 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-07 10:25:14 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_InHist_PmManage_Raw | 2026-04-07 09:21:25 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-07 09:21:55 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-04-07 09:20:25 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-04-07 09:17:55 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-07 09:23:26 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-07 09:27:56 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-07 09:23:25 | -1.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-07 09:30:37 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-07 09:30:07 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-07 09:34:19 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-07 09:32:07 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-07 09:31:08 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-07 09:31:09 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-07 09:31:07 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-07 09:35:50 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-07 09:35:50 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-07 09:39:58 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-07 09:38:59 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-07 09:34:49 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-07 09:38:59 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-07 09:38:59 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-07 09:34:20 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-07 09:34:19 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-07 09:38:29 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-07 09:38:59 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-07 09:38:29 | -1.6 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-07 09:42:42 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-07 09:42:41 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-07 09:42:41 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-07 09:43:10 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-07 09:42:41 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-07 09:42:11 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-07 09:42:41 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-04-07 09:43:11 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-07 09:42:41 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

