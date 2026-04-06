# Data Freshness Report

**Generated:** 2026-04-06 08:01:19
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

- **df_Dim_Source** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (115.5 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (115.5 hours ago)
- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-04-01 12:33:15 (115.5 hours ago)
- **df_Dim_Location** (Dimension) - Last refreshed: 2026-04-01 12:32:12 (115.5 hours ago)
- **df_Dim_PaymentMethod** (Dimension) - Last refreshed: 2026-04-01 12:36:30 (115.4 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-04-01 12:36:33 (115.4 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-04-01 12:36:29 (115.4 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-04-01 12:34:17 (115.4 hours ago)
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-04-01 12:36:59 (115.4 hours ago)
- **df_Dim_JobType** (Dimension) - Last refreshed: 2026-04-01 12:39:11 (115.4 hours ago)
- **df_Dim_AdjustmentType** (Dimension) - Last refreshed: 2026-04-01 12:35:59 (115.4 hours ago)
- **df_Dim_PromoType** (Dimension) - Last refreshed: 2026-04-01 12:43:40 (115.3 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_DealerGroupCode | 2026-04-01 12:33:15 | 115.5 | [CRIT] Critical |
| df_Dim_Location | 2026-04-01 12:32:12 | 115.5 | [CRIT] Critical |
| df_Dim_SLC | 2026-04-01 12:32:43 | 115.5 | [CRIT] Critical |
| df_Dim_Source | 2026-04-01 12:32:43 | 115.5 | [CRIT] Critical |
| df_Dim_JobType | 2026-04-01 12:39:11 | 115.4 | [CRIT] Critical |
| df_Dim_VendorCode | 2026-04-01 12:36:33 | 115.4 | [CRIT] Critical |
| df_Dim_PaymentMethod | 2026-04-01 12:36:30 | 115.4 | [CRIT] Critical |
| df_Dim_ModuleType | 2026-04-01 12:36:29 | 115.4 | [CRIT] Critical |
| df_Dim_CommodityCode | 2026-04-01 12:36:59 | 115.4 | [CRIT] Critical |
| df_Dim_Franchise | 2026-04-01 12:34:17 | 115.4 | [CRIT] Critical |
| df_Dim_AdjustmentType | 2026-04-01 12:35:59 | 115.4 | [CRIT] Critical |
| df_Dim_PromoType | 2026-04-01 12:43:40 | 115.3 | [CRIT] Critical |
| df_Dim_Customer | 2026-04-06 09:48:47 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-04-06 09:47:48 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-04-06 09:50:47 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-06 09:52:58 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-06 09:53:27 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-06 09:52:57 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-06 09:53:57 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-06 09:52:58 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-06 09:52:58 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-06 09:56:18 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-06 10:00:48 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-06 10:00:48 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-06 09:59:48 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-06 10:03:18 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-06 10:01:48 | -2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-06 10:07:43 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-06 10:08:59 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-06 10:08:14 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-06 10:07:12 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-06 10:07:14 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-06 10:07:41 | -2.1 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-06 10:12:43 | -2.2 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-06 10:14:58 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-06 10:11:13 | -2.2 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-06 10:15:29 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-06 10:11:52 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-06 10:14:57 | -2.2 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-06 10:15:00 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-06 10:15:29 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-06 10:11:45 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-06 10:11:44 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-06 10:19:29 | -2.3 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-06 10:21:45 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-06 10:22:15 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-06 10:22:16 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-06 10:22:16 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-06 10:22:44 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_InHist_PmManage_Raw | 2026-04-06 09:21:25 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-06 09:21:25 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-04-06 09:19:55 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-04-06 09:17:55 | -1.3 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-06 09:27:25 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-06 09:22:55 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-06 09:23:25 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-06 09:29:37 | -1.5 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-06 09:33:51 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-06 09:33:50 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-06 09:29:38 | -1.5 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-06 09:33:54 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-06 09:30:08 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-06 09:30:07 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-06 09:31:37 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-06 09:30:36 | -1.5 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-06 09:33:50 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-06 09:39:04 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-06 09:35:20 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-06 09:38:04 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-06 09:38:04 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-06 09:35:21 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-06 09:37:34 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-06 09:37:34 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-06 09:38:04 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-06 09:38:04 | -1.6 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-06 09:41:48 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-06 09:41:48 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-06 09:41:48 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-06 09:41:51 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-06 09:41:48 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-06 09:41:51 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-06 09:41:48 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-04-06 09:41:48 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-06 09:41:49 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

