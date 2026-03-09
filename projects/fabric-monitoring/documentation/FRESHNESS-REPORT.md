# Data Freshness Report

**Generated:** 2026-03-09 06:01:32
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 51 | 42.5% |
| Stale | 19 | 15.8% |
| Critical | 44 | 36.7% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_PartTransactions** (FactTable) - Never refreshed!
- **df_Fact_Part_Transactions** (FactTable) - Never refreshed!
- **df_Fact_WarrantyClaims** (FactTable) - Never refreshed!
- **df_Fact_WorkOrderHeader** (FactTable) - Never refreshed!
- **df_Fact_WorkOrderComprehensive** (FactTable) - Never refreshed!
- **df_Fact_LaborJobs** (FactTable) - Never refreshed!
- **df_Fact_LaborInvoiced** (FactTable) - Never refreshed!
- **df_Fact_LaborPunches** (FactTable) - Never refreshed!
- **df_Fact_Machines_Serviced** (FactTable) - Never refreshed!
- **df_Fact_LaborWIP** (FactTable) - Never refreshed!
- **df_Fact_WorkOrderJobs** (FactTable) - Never refreshed!
- **df_Transform_Jobs** (Transformation) - Never refreshed!
- **df_Transform_jdis_Part_Information** (Transformation) - Never refreshed!
- **df_Transform_Parts** (Transformation) - Never refreshed!
- **Equipment Service - Data Quality Validation** (AdHoc) - Never refreshed!
- **df_Transform_Vehicles** (Transformation) - Never refreshed!
- **df_INTRANS_Raw** (RawSource) - Never refreshed!
- **df_Fact_WorkOrderLabor** (FactTable) - Never refreshed!
- **df_jdis_Part_Information_Verification** (AdHoc) - Never refreshed!
- **df_Transform_Customers** (Transformation) - Never refreshed!
- **df_Part_Master_Duplicate_Analysis** (AdHoc) - Never refreshed!
- **df_Fact_InvoiceHeader** (FactTable) - Never refreshed!
- **df_Dim_BranchFranchise** (Dimension) - Never refreshed!
- **df_DealerGroupCode_Analysis** (AdHoc) - Never refreshed!
- **df_Dim_SlicerControl** (Dimension) - Never refreshed!
- **df_Dim_InvoiceType** (Dimension) - Never refreshed!
- **df_Dim_InvoiceLookup** (Dimension) - Never refreshed!
- **df_CustomerAnatomy_Raw** (RawSource) - Never refreshed!
- **df_Dim_WorkOrderType** (Dimension) - Never refreshed!
- **df_Customer_ID_Analysis** (AdHoc) - Never refreshed!
- **df_Dim_WorkOrderStatus** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderLookup** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderMaster** (Dimension) - Never refreshed!
- **df_Engaged_Acres** (AdHoc) - Last refreshed: 2026-02-11 21:57:52 (608.1 hours ago)
- **df_InMaster_Raw** (RawSource) - Last refreshed: 2026-02-13 14:36:17 (567.4 hours ago)
- **df_Dim_Vehicle** (Dimension) - Last refreshed: 2026-02-19 15:53:04 (422.1 hours ago)
- **df_Dim_DealerGroupCode** (Dimension) - Last refreshed: 2026-02-19 18:52:02 (419.2 hours ago)
- **df_Dim_Source** (Dimension) - Last refreshed: 2026-02-19 18:51:32 (419.2 hours ago)
- **df_Dim_Franchise** (Dimension) - Last refreshed: 2026-02-19 18:51:32 (419.2 hours ago)
- **df_Dim_Location** (Dimension) - Last refreshed: 2026-02-19 18:51:32 (419.2 hours ago)
- **df_Dim_SLC** (Dimension) - Last refreshed: 2026-02-19 18:51:33 (419.2 hours ago)
- **df_Dim_VendorCode** (Dimension) - Last refreshed: 2026-02-19 18:57:19 (419.1 hours ago)
- **df_Dim_ModuleType** (Dimension) - Last refreshed: 2026-02-19 18:54:12 (419.1 hours ago)
- **df_Dim_RepairOrder** (Dimension) - Last refreshed: 2026-02-19 19:00:28 (419 hours ago)

---

## Stale - Monitor Closely

The following dataflows are approaching staleness:

- **df_Fact_LaborJobSummary** (FactTable) - Last refreshed: 2026-03-06 11:38:42 (66.4 hours ago)
- **df_Fact_Parts_Invoices** (FactTable) - Last refreshed: 2026-03-06 11:39:39 (66.4 hours ago)
- **df_Fact_Service_Parts_Detail** (FactTable) - Last refreshed: 2026-03-06 11:37:39 (66.4 hours ago)
- **df_Fact_First_Pass_Fill** (FactTable) - Last refreshed: 2026-03-06 11:39:11 (66.4 hours ago)
- **df_Fact_CustomerPerformance** (FactTable) - Last refreshed: 2026-03-06 11:37:40 (66.4 hours ago)
- **df_Fact_Parts_With_Open_Orders** (FactTable) - Last refreshed: 2026-03-06 11:45:21 (66.3 hours ago)
- **df_Fact_PartsAdjustments** (FactTable) - Last refreshed: 2026-03-06 11:44:23 (66.3 hours ago)
- **df_Fact_Invoice_UniqueCustomers** (FactTable) - Last refreshed: 2026-03-06 11:41:40 (66.3 hours ago)
- **df_Fact_Branch12_Transactions** (FactTable) - Last refreshed: 2026-03-06 11:44:22 (66.3 hours ago)
- **df_Fact_PartSales_24Hours** (FactTable) - Last refreshed: 2026-03-06 11:45:22 (66.3 hours ago)
- **df_Fact_Invoice_InventoryAnalysis** (FactTable) - Last refreshed: 2026-03-06 11:44:51 (66.3 hours ago)
- **df_Fact_PendingInspections** (FactTable) - Last refreshed: 2026-03-06 11:48:03 (66.2 hours ago)
- **df_Fact_Equipment_Sales** (FactTable) - Last refreshed: 2026-03-06 11:48:04 (66.2 hours ago)
- **df_Fact_InTrans_UniqueCustomers** (FactTable) - Last refreshed: 2026-03-06 11:50:05 (66.2 hours ago)
- **df_Fact_Transfers** (FactTable) - Last refreshed: 2026-03-06 11:51:33 (66.2 hours ago)
- **df_Fact_NegativeOnHand_OnHandNoBin** (FactTable) - Last refreshed: 2026-03-06 11:53:49 (66.1 hours ago)
- **df_Fact_Top50_JobCodes** (FactTable) - Last refreshed: 2026-03-06 11:54:48 (66.1 hours ago)
- **df_Fact_PartsPromo** (FactTable) - Last refreshed: 2026-03-06 11:53:49 (66.1 hours ago)
- **df_Fact_InSalOrd_InSalPar** (FactTable) - Last refreshed: 2026-03-06 11:53:49 (66.1 hours ago)

---

## Freshness by Category

### AdHoc

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_jdis_Part_Information_Verification | Never | 999999 | [NEVER] Never Refreshed |
| df_Part_Master_Duplicate_Analysis | Never | 999999 | [NEVER] Never Refreshed |
| Equipment Service - Data Quality Validation | Never | 999999 | [NEVER] Never Refreshed |
| df_DealerGroupCode_Analysis | Never | 999999 | [NEVER] Never Refreshed |
| df_Customer_ID_Analysis | Never | 999999 | [NEVER] Never Refreshed |
| df_Engaged_Acres | 2026-02-11 21:57:52 | 608.1 | [CRIT] Critical |
| DF_PartMaster_Snapshot_Weekly | 2026-03-08 07:05:32 | 22.9 | [OK] Fresh |
| DF_PartMaster_Snapshot_Daily | 2026-03-09 07:04:33 | -1.1 | [OK] Fresh |
| df_CustomerLookup | 2026-03-09 09:50:51 | -3.8 | [OK] Fresh |
| df_InTrans_Incremental | 2026-03-09 09:47:41 | -3.8 | [OK] Fresh |
| df_UniqueCustomer_Lookup | 2026-03-09 09:52:51 | -3.9 | [OK] Fresh |

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_InvoiceLookup | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderMaster | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderStatus | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_InvoiceType | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchFranchise | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderType | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderLookup | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_SlicerControl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Vehicle | 2026-02-19 15:53:04 | 422.1 | [CRIT] Critical |
| df_Dim_SLC | 2026-02-19 18:51:33 | 419.2 | [CRIT] Critical |
| df_Dim_Source | 2026-02-19 18:51:32 | 419.2 | [CRIT] Critical |
| df_Dim_Location | 2026-02-19 18:51:32 | 419.2 | [CRIT] Critical |
| df_Dim_DealerGroupCode | 2026-02-19 18:52:02 | 419.2 | [CRIT] Critical |
| df_Dim_Franchise | 2026-02-19 18:51:32 | 419.2 | [CRIT] Critical |
| df_Dim_VendorCode | 2026-02-19 18:57:19 | 419.1 | [CRIT] Critical |
| df_Dim_ModuleType | 2026-02-19 18:54:12 | 419.1 | [CRIT] Critical |
| df_Dim_RepairOrder | 2026-02-19 19:00:28 | 419 | [CRIT] Critical |
| df_Dim_Date | 2026-03-09 09:51:21 | -3.8 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-03-09 09:57:00 | -3.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-03-09 09:56:31 | -3.9 | [OK] Fresh |
| df_Dim_Customer | 2026-03-09 09:52:21 | -3.9 | [OK] Fresh |
| df_Dim_Part | 2026-03-09 09:54:21 | -3.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-03-09 09:57:00 | -3.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-03-09 09:57:00 | -3.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_LaborWIP | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WarrantyClaims | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborPunches | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborInvoiced | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborJobs | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderHeader | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderComprehensive | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PartTransactions | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Part_Transactions | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderJobs | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderLabor | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Machines_Serviced | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_InvoiceHeader | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Parts_Invoices | 2026-03-06 11:39:39 | 66.4 | [WARN] Stale |
| df_Fact_CustomerPerformance | 2026-03-06 11:37:40 | 66.4 | [WARN] Stale |
| df_Fact_First_Pass_Fill | 2026-03-06 11:39:11 | 66.4 | [WARN] Stale |
| df_Fact_LaborJobSummary | 2026-03-06 11:38:42 | 66.4 | [WARN] Stale |
| df_Fact_Service_Parts_Detail | 2026-03-06 11:37:39 | 66.4 | [WARN] Stale |
| df_Fact_PartsAdjustments | 2026-03-06 11:44:23 | 66.3 | [WARN] Stale |
| df_Fact_PartSales_24Hours | 2026-03-06 11:45:22 | 66.3 | [WARN] Stale |
| df_Fact_Branch12_Transactions | 2026-03-06 11:44:22 | 66.3 | [WARN] Stale |
| df_Fact_Invoice_UniqueCustomers | 2026-03-06 11:41:40 | 66.3 | [WARN] Stale |
| df_Fact_Invoice_InventoryAnalysis | 2026-03-06 11:44:51 | 66.3 | [WARN] Stale |
| df_Fact_Parts_With_Open_Orders | 2026-03-06 11:45:21 | 66.3 | [WARN] Stale |
| df_Fact_Transfers | 2026-03-06 11:51:33 | 66.2 | [WARN] Stale |
| df_Fact_InTrans_UniqueCustomers | 2026-03-06 11:50:05 | 66.2 | [WARN] Stale |
| df_Fact_Equipment_Sales | 2026-03-06 11:48:04 | 66.2 | [WARN] Stale |
| df_Fact_PendingInspections | 2026-03-06 11:48:03 | 66.2 | [WARN] Stale |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-03-06 11:53:49 | 66.1 | [WARN] Stale |
| df_Fact_Top50_JobCodes | 2026-03-06 11:54:48 | 66.1 | [WARN] Stale |
| df_Fact_InSalOrd_InSalPar | 2026-03-06 11:53:49 | 66.1 | [WARN] Stale |
| df_Fact_PartsPromo | 2026-03-06 11:53:49 | 66.1 | [WARN] Stale |
| df_FactPartTransactions_Incremental | 2026-03-09 10:02:23 | -4 | [OK] Fresh |
| df_Fact_Inventory | 2026-03-09 10:07:23 | -4.1 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-03-09 10:06:53 | -4.1 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-03-09 10:08:22 | -4.1 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-03-09 10:13:53 | -4.2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-03-09 10:19:05 | -4.3 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_CustomerAnatomy_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_INTRANS_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_InMaster_Raw | 2026-02-13 14:36:17 | 567.4 | [CRIT] Critical |
| df_GlTrans_Raw | 2026-03-09 09:20:43 | -3.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-03-09 09:20:43 | -3.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-03-09 09:17:12 | -3.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-03-09 09:19:12 | -3.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-03-09 09:22:12 | -3.3 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-03-09 09:22:42 | -3.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-03-09 09:26:42 | -3.4 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-03-09 09:29:25 | -3.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-03-09 09:30:25 | -3.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-03-09 09:29:54 | -3.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-03-09 09:29:54 | -3.5 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-03-09 09:33:33 | -3.5 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-03-09 09:38:14 | -3.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-03-09 09:40:25 | -3.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-03-09 09:37:14 | -3.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-03-09 09:37:45 | -3.6 | [OK] Fresh |
| df_INSALORD_Raw | 2026-03-09 09:35:44 | -3.6 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-03-09 09:37:14 | -3.6 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-03-09 09:36:44 | -3.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-03-09 09:44:37 | -3.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-03-09 09:44:37 | -3.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-03-09 09:44:38 | -3.7 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-03-09 09:45:08 | -3.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-03-09 09:45:07 | -3.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-03-09 09:44:37 | -3.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-03-09 09:44:37 | -3.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-03-09 09:40:55 | -3.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-03-09 09:40:55 | -3.7 | [OK] Fresh |
| df_Technician_Raw | 2026-03-09 09:44:37 | -3.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-03-09 09:41:55 | -3.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-03-09 09:44:37 | -3.7 | [OK] Fresh |
| df_VhTrans_Raw | 2026-03-09 09:40:55 | -3.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-03-09 09:40:55 | -3.7 | [OK] Fresh |

### Transformation

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Transform_Parts | Never | 999999 | [NEVER] Never Refreshed |
| df_Transform_Vehicles | Never | 999999 | [NEVER] Never Refreshed |
| df_Transform_Jobs | Never | 999999 | [NEVER] Never Refreshed |
| df_Transform_Customers | Never | 999999 | [NEVER] Never Refreshed |
| df_Transform_jdis_Part_Information | Never | 999999 | [NEVER] Never Refreshed |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

