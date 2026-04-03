# Data Freshness Report

**Generated:** 2026-04-03 08:01:17
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 72 | 85.7% |
| Stale | 12 | 14.3% |
| Critical | 0 | 0% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_Dim_Source** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (43.5 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-04-01 12:32:43 (43.5 hours ago)
- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-04-01 12:33:15 (43.5 hours ago)
- **df_Dim_Location** (Dimension) - Last refreshed: 2026-04-01 12:32:12 (43.5 hours ago)
- **df_Dim_PaymentMethod** (Dimension) - Last refreshed: 2026-04-01 12:36:30 (43.4 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-04-01 12:36:33 (43.4 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-04-01 12:36:29 (43.4 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-04-01 12:34:17 (43.4 hours ago)
- **df_Dim_CommodityCode** (Dimension) - Last refreshed: 2026-04-01 12:36:59 (43.4 hours ago)
- **df_Dim_JobType** (Dimension) - Last refreshed: 2026-04-01 12:39:11 (43.4 hours ago)
- **df_Dim_AdjustmentType** (Dimension) - Last refreshed: 2026-04-01 12:35:59 (43.4 hours ago)
- **df_Dim_PromoType** (Dimension) - Last refreshed: 2026-04-01 12:43:40 (43.3 hours ago)

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_DealerGroupCode | 2026-04-01 12:33:15 | 43.5 | [WARN] Stale |
| df_Dim_Location | 2026-04-01 12:32:12 | 43.5 | [WARN] Stale |
| df_Dim_SLC | 2026-04-01 12:32:43 | 43.5 | [WARN] Stale |
| df_Dim_Source | 2026-04-01 12:32:43 | 43.5 | [WARN] Stale |
| df_Dim_JobType | 2026-04-01 12:39:11 | 43.4 | [WARN] Stale |
| df_Dim_VendorCode | 2026-04-01 12:36:33 | 43.4 | [WARN] Stale |
| df_Dim_PaymentMethod | 2026-04-01 12:36:30 | 43.4 | [WARN] Stale |
| df_Dim_ModuleType | 2026-04-01 12:36:29 | 43.4 | [WARN] Stale |
| df_Dim_CommodityCode | 2026-04-01 12:36:59 | 43.4 | [WARN] Stale |
| df_Dim_Franchise | 2026-04-01 12:34:17 | 43.4 | [WARN] Stale |
| df_Dim_AdjustmentType | 2026-04-01 12:35:59 | 43.4 | [WARN] Stale |
| df_Dim_PromoType | 2026-04-01 12:43:40 | 43.3 | [WARN] Stale |
| df_Dim_Customer | 2026-04-03 09:49:53 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-04-03 09:48:53 | -1.8 | [OK] Fresh |
| df_Dim_Part | 2026-04-03 09:51:53 | -1.8 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-03 09:54:04 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-03 09:54:04 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-03 09:54:09 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-03 09:55:03 | -1.9 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-03 09:54:05 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-03 09:54:03 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-03 09:57:30 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-03 10:03:02 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-03 10:02:30 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-03 10:03:00 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-03 10:01:00 | -2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-03 10:39:15 | -2.6 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-03 10:39:45 | -2.6 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-03 10:35:33 | -2.6 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-03 10:39:15 | -2.6 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-03 10:42:56 | -2.7 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-03 10:40:45 | -2.7 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-03 10:44:26 | -2.7 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-03 10:42:56 | -2.7 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-03 10:40:15 | -2.7 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-03 10:43:26 | -2.7 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-03 10:40:15 | -2.7 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-03 10:43:57 | -2.7 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-03 10:47:07 | -2.8 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-03 10:47:07 | -2.8 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-03 10:46:37 | -2.8 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-03 10:47:37 | -2.8 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-03 10:50:37 | -2.8 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-03 10:47:07 | -2.8 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-03 10:52:50 | -2.9 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-03 10:53:49 | -2.9 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-03 10:53:18 | -2.9 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-03 10:52:49 | -2.9 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-03 10:52:49 | -2.9 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_WKROFILE_Raw | 2026-04-03 09:20:34 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-04-03 09:18:04 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-03 09:22:05 | -1.3 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-03 09:22:04 | -1.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-03 09:23:34 | -1.4 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-03 09:24:05 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-03 09:28:34 | -1.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-03 09:30:45 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-03 09:31:18 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-03 09:32:46 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-03 09:31:45 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-03 09:31:46 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-03 09:31:46 | -1.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-03 09:36:29 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-03 09:35:59 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-03 09:39:13 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-03 09:40:13 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-03 09:39:12 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-03 09:35:29 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-03 09:39:13 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-03 09:34:59 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-03 09:38:42 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-03 09:34:59 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-03 09:34:59 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-03 09:39:12 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-03 09:39:12 | -1.6 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-03 09:42:56 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-03 09:42:56 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-03 09:42:56 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-03 09:42:56 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-03 09:42:56 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-03 09:42:56 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-03 09:42:56 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-04-03 09:42:56 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-03 09:42:26 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

