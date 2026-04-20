# Data Freshness Report

**Generated:** 2026-04-20 08:01:31
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 73 | 83% |
| Stale |  | 0% |
| Critical | 13 | 14.8% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Dim_Location** (Dimension) - Last refreshed: 2026-04-01 12:32:12 (451.5 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (451.5 hours ago)
- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-04-01 12:33:15 (451.5 hours ago)
- **df_Dim_Source** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (451.5 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-04-01 12:36:33 (451.4 hours ago)
- **df_Dim_PaymentMethod** (Dimension) - Last refreshed: 2026-04-01 12:36:30 (451.4 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-04-01 12:36:29 (451.4 hours ago)
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-04-01 12:36:59 (451.4 hours ago)
- **df_Dim_AdjustmentType** (Dimension) - Last refreshed: 2026-04-01 12:35:59 (451.4 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-04-01 12:34:17 (451.4 hours ago)
- **df_Dim_JobType** (Dimension) - Last refreshed: 2026-04-01 12:39:11 (451.4 hours ago)
- **df_Dim_PromoType** (Dimension) - Last refreshed: 2026-04-01 12:43:40 (451.3 hours ago)
- **df_GlTrans_Full_Raw** (RawSource) - Last refreshed: 2026-04-16 01:32:30 (102.5 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_SLC | 2026-04-01 12:32:43 | 451.5 | [CRIT] Critical |
| df_Dim_DealerGroupCode | 2026-04-01 12:33:15 | 451.5 | [CRIT] Critical |
| df_Dim_Source | 2026-04-01 12:32:43 | 451.5 | [CRIT] Critical |
| df_Dim_Location | 2026-04-01 12:32:12 | 451.5 | [CRIT] Critical |
| df_Dim_JobType | 2026-04-01 12:39:11 | 451.4 | [CRIT] Critical |
| df_Dim_AdjustmentType | 2026-04-01 12:35:59 | 451.4 | [CRIT] Critical |
| df_Dim_VendorCode | 2026-04-01 12:36:33 | 451.4 | [CRIT] Critical |
| df_Dim_PaymentMethod | 2026-04-01 12:36:30 | 451.4 | [CRIT] Critical |
| df_Dim_ModuleType | 2026-04-01 12:36:29 | 451.4 | [CRIT] Critical |
| df_Dim_CommodityCode | 2026-04-01 12:36:59 | 451.4 | [CRIT] Critical |
| df_Dim_Franchise | 2026-04-01 12:34:17 | 451.4 | [CRIT] Critical |
| df_Dim_PromoType | 2026-04-01 12:43:40 | 451.3 | [CRIT] Critical |
| df_Dim_BranchUserAccess | 2026-04-17 14:51:30 | 65.2 | [WARN] Stale |
| df_Dim_Customer | 2026-04-20 10:06:48 | -2.1 | [OK] Fresh |
| df_Dim_Date | 2026-04-20 10:05:52 | -2.1 | [OK] Fresh |
| df_Dim_Part | 2026-04-20 10:08:51 | -2.1 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-20 10:11:21 | -2.2 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-20 10:11:21 | -2.2 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-20 10:11:21 | -2.2 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-20 10:11:51 | -2.2 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-20 10:12:24 | -2.2 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-20 10:11:26 | -2.2 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-20 10:14:55 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-20 10:20:23 | -2.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-20 10:19:51 | -2.3 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-20 10:18:53 | -2.3 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-20 10:20:51 | -2.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-20 10:20:54 | -2.3 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-20 10:25:05 | -2.4 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-20 10:26:35 | -2.4 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-20 10:25:35 | -2.4 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-20 10:25:35 | -2.4 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-20 10:24:35 | -2.4 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-20 10:24:36 | -2.4 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-20 10:29:17 | -2.5 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-20 10:29:17 | -2.5 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-20 10:32:58 | -2.5 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-20 10:30:47 | -2.5 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-20 10:29:17 | -2.5 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-20 10:33:29 | -2.5 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-20 10:29:46 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-20 10:33:29 | -2.5 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-20 10:33:27 | -2.5 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-04-20 10:39:41 | -2.6 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-20 10:40:10 | -2.6 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-20 10:36:58 | -2.6 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-20 10:39:40 | -2.6 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-20 10:34:29 | -2.6 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-20 10:39:40 | -2.6 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-20 10:39:42 | -2.6 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-20 10:39:42 | -2.6 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 102.5 | [CRIT] Critical |
| df_Parts_InterbranchTransfer_Raw | 2026-04-20 09:17:56 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-04-20 09:20:26 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-20 09:21:56 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-20 09:22:26 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-20 09:23:56 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-20 09:25:56 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-20 09:42:40 | -1.7 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-20 09:44:52 | -1.7 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-20 09:45:52 | -1.7 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-20 09:45:52 | -1.7 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-20 09:45:52 | -1.7 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-20 09:45:22 | -1.7 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-20 09:50:03 | -1.8 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-20 09:50:34 | -1.8 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-20 09:51:04 | -1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-20 09:49:34 | -1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-20 09:49:33 | -1.8 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-20 09:47:22 | -1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-20 09:49:33 | -1.8 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-20 09:57:28 | -1.9 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-20 09:57:28 | -1.9 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-20 09:57:28 | -1.9 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-20 09:57:28 | -1.9 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-20 09:57:28 | -1.9 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-20 09:57:28 | -1.9 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-20 09:57:28 | -1.9 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-20 09:56:58 | -1.9 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-20 09:53:51 | -1.9 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-20 09:53:51 | -1.9 | [OK] Fresh |
| df_Technician_Raw | 2026-04-20 09:57:28 | -1.9 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-20 09:53:15 | -1.9 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-20 09:53:45 | -1.9 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-20 09:53:45 | -1.9 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-20 09:53:15 | -1.9 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-20 09:54:45 | -1.9 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

