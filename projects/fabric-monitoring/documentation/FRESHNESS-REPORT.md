# Data Freshness Report

**Generated:** 2026-04-16 08:01:31
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 75 | 85.2% |
| Stale | 0 | 0% |
| Critical | 12 | 13.6% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Dim_Source** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (355.5 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (355.5 hours ago)
- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-04-01 12:33:15 (355.5 hours ago)
- **df_Dim_Location** (Dimension) - Last refreshed: 2026-04-01 12:32:12 (355.5 hours ago)
- **df_Dim_PaymentMethod** (Dimension) - Last refreshed: 2026-04-01 12:36:30 (355.4 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-04-01 12:36:33 (355.4 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-04-01 12:36:29 (355.4 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-04-01 12:34:17 (355.4 hours ago)
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-04-01 12:36:59 (355.4 hours ago)
- **df_Dim_JobType** (Dimension) - Last refreshed: 2026-04-01 12:39:11 (355.4 hours ago)
- **df_Dim_AdjustmentType** (Dimension) - Last refreshed: 2026-04-01 12:35:59 (355.4 hours ago)
- **df_Dim_PromoType** (Dimension) - Last refreshed: 2026-04-01 12:43:40 (355.3 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_SLC | 2026-04-01 12:32:43 | 355.5 | [CRIT] Critical |
| df_Dim_DealerGroupCode | 2026-04-01 12:33:15 | 355.5 | [CRIT] Critical |
| df_Dim_Source | 2026-04-01 12:32:43 | 355.5 | [CRIT] Critical |
| df_Dim_Location | 2026-04-01 12:32:12 | 355.5 | [CRIT] Critical |
| df_Dim_JobType | 2026-04-01 12:39:11 | 355.4 | [CRIT] Critical |
| df_Dim_AdjustmentType | 2026-04-01 12:35:59 | 355.4 | [CRIT] Critical |
| df_Dim_VendorCode | 2026-04-01 12:36:33 | 355.4 | [CRIT] Critical |
| df_Dim_PaymentMethod | 2026-04-01 12:36:30 | 355.4 | [CRIT] Critical |
| df_Dim_ModuleType | 2026-04-01 12:36:29 | 355.4 | [CRIT] Critical |
| df_Dim_Franchise | 2026-04-01 12:34:17 | 355.4 | [CRIT] Critical |
| df_Dim_CommodityCode | 2026-04-01 12:36:59 | 355.4 | [CRIT] Critical |
| df_Dim_PromoType | 2026-04-01 12:43:40 | 355.3 | [CRIT] Critical |
| df_Dim_Customer | 2026-04-15 09:50:14 | 22.2 | [OK] Fresh |
| df_Dim_Date | 2026-04-15 09:49:16 | 22.2 | [OK] Fresh |
| df_Dim_Part | 2026-04-15 09:52:14 | 22.2 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-15 09:54:27 | 22.1 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-15 09:54:26 | 22.1 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-15 09:54:28 | 22.1 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-15 09:54:55 | 22.1 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-15 09:54:56 | 22.1 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-15 09:54:26 | 22.1 | [OK] Fresh |
| df_Dim_BranchUserAccess | 2026-04-15 21:33:59 | 10.5 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-15 09:57:23 | 22.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-15 10:01:54 | 22 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-15 10:01:54 | 22 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-15 10:00:54 | 22 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-15 10:02:53 | 22 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-15 10:02:23 | 22 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-15 10:07:30 | 21.9 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-15 10:08:18 | 21.9 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-15 10:07:52 | 21.9 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-15 10:07:17 | 21.9 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-15 10:06:53 | 21.9 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-15 10:06:49 | 21.9 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-15 10:10:38 | 21.8 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-15 10:11:11 | 21.8 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-15 10:14:53 | 21.8 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-15 10:14:53 | 21.8 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-15 10:11:23 | 21.8 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-15 10:14:53 | 21.8 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-15 10:11:15 | 21.8 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-15 10:14:53 | 21.8 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-15 10:14:53 | 21.8 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-04-15 10:21:16 | 21.7 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-15 10:21:45 | 21.7 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-15 10:18:24 | 21.7 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-15 10:21:45 | 21.7 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-15 10:21:19 | 21.7 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-15 10:21:16 | 21.7 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-15 10:21:15 | 21.7 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-15 16:17:37 | 15.7 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_WKMECHWK_Raw | 2026-04-15 09:31:35 | 22.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-15 09:30:35 | 22.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-15 09:32:43 | 22.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-15 09:31:05 | 22.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-15 09:31:35 | 22.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-15 09:31:37 | 22.5 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-15 09:39:11 | 22.4 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-15 09:36:24 | 22.4 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-15 09:34:59 | 22.4 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-15 09:38:38 | 22.4 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-15 09:39:08 | 22.4 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-15 09:39:13 | 22.4 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-15 09:39:08 | 22.4 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-15 09:35:00 | 22.4 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-15 09:35:56 | 22.4 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-15 09:40:08 | 22.4 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-15 09:35:00 | 22.4 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-15 09:34:55 | 22.4 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-15 09:38:38 | 22.4 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-15 09:42:57 | 22.3 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-15 09:42:53 | 22.3 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-15 09:42:53 | 22.3 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-15 09:42:52 | 22.3 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-15 09:42:23 | 22.3 | [OK] Fresh |
| df_Technician_Raw | 2026-04-15 09:43:22 | 22.3 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-15 09:42:55 | 22.3 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-15 09:42:52 | 22.3 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-15 09:42:54 | 22.3 | [OK] Fresh |
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 6.5 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-04-16 09:20:30 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-16 09:22:00 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-04-16 09:18:00 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-16 09:23:30 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-16 09:23:30 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-16 09:27:00 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-16 09:42:35 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

