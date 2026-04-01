# Data Freshness Report

**Generated:** 2026-04-01 08:01:31
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 80 | 98.8% |
| Stale | 0 | 0% |
| Critical | 0 | 0% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_Date | 2026-04-01 09:51:41 | -1.8 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-01 09:56:51 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-01 09:56:52 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-01 09:56:51 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-01 09:56:51 | -1.9 | [OK] Fresh |
| df_Dim_Part | 2026-04-01 09:54:41 | -1.9 | [OK] Fresh |
| df_Dim_Customer | 2026-04-01 09:52:41 | -1.9 | [OK] Fresh |
| df_Dim_Source | 2026-04-01 12:32:43 | -4.5 | [OK] Fresh |
| df_Dim_SLC | 2026-04-01 12:32:43 | -4.5 | [OK] Fresh |
| df_Dim_DealerGroupCode | 2026-04-01 12:33:15 | -4.5 | [OK] Fresh |
| df_Dim_Location | 2026-04-01 12:32:12 | -4.5 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-01 12:40:10 | -4.6 | [OK] Fresh |
| df_Dim_VendorCode | 2026-04-01 12:36:33 | -4.6 | [OK] Fresh |
| df_Dim_CommodityCode | 2026-04-01 12:36:59 | -4.6 | [OK] Fresh |
| df_Dim_JobType | 2026-04-01 12:39:11 | -4.6 | [OK] Fresh |
| df_Dim_Franchise | 2026-04-01 12:34:17 | -4.6 | [OK] Fresh |
| df_Dim_AdjustmentType | 2026-04-01 12:35:59 | -4.6 | [OK] Fresh |
| df_Dim_PaymentMethod | 2026-04-01 12:36:30 | -4.6 | [OK] Fresh |
| df_Dim_ModuleType | 2026-04-01 12:36:29 | -4.6 | [OK] Fresh |
| df_Dim_PromoType | 2026-04-01 12:43:40 | -4.7 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_Service_Detail | 2026-04-01 10:03:45 | -2 | [OK] Fresh |
| df_FactPartTransactions_Incremental | 2026-04-01 10:00:13 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-01 10:05:43 | -2.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-01 10:04:43 | -2.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-01 10:06:44 | -2.1 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-01 10:04:44 | -2.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-01 10:15:04 | -2.2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-01 10:12:12 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-01 10:14:34 | -2.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-01 10:10:42 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-01 10:16:07 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-01 10:15:11 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-01 10:15:34 | -2.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-01 10:11:42 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-01 10:11:12 | -2.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-01 10:10:42 | -2.2 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-01 10:12:13 | -2.2 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-01 10:18:50 | -2.3 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-01 10:21:51 | -2.3 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-01 10:18:50 | -2.3 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-01 10:18:22 | -2.3 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-01 10:24:35 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-01 10:25:07 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-01 10:24:36 | -2.4 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-01 10:24:36 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-01 10:24:06 | -2.4 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_WKROFILE_Raw | 2026-04-01 09:20:13 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-04-01 09:17:13 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-01 09:22:13 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-01 09:24:13 | -1.4 | [OK] Fresh |
| df_GlTrans_Raw | 2026-04-01 09:25:13 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-01 09:23:13 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-01 09:27:13 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-01 09:29:23 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-01 09:29:23 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-01 09:30:23 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-01 09:30:24 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-01 09:30:23 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-01 09:38:42 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-01 09:39:13 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-01 09:38:13 | -1.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-01 09:38:13 | -1.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-01 09:37:43 | -1.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-01 09:37:43 | -1.6 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-01 09:35:30 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-01 09:42:24 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-01 09:46:06 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-01 09:46:06 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-01 09:45:36 | -1.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-01 09:41:54 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-01 09:46:07 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-01 09:46:06 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-01 09:46:06 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-01 09:46:06 | -1.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-01 09:46:06 | -1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-01 09:42:24 | -1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-01 09:43:24 | -1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-01 09:41:53 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-04-01 09:46:06 | -1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-01 09:41:24 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

