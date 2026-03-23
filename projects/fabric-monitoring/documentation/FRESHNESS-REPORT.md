# Data Freshness Report

**Generated:** 2026-03-23 11:21:45
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 71 | 59.2% |
| Stale | 0 | 0% |
| Critical | 36 | 30% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Critical - Immediate Attention Required

The following dataflows need immediate attention:

- **df_Fact_WorkOrderHeader** (FactTable) - Never refreshed!
- **df_Fact_WorkOrderComprehensive** (FactTable) - Never refreshed!
- **df_Fact_WorkOrderLabor** (FactTable) - Never refreshed!
- **df_Fact_WorkOrderJobs** (FactTable) - Never refreshed!
- **df_Fact_WarrantyClaims** (FactTable) - Never refreshed!
- **df_Fact_Machines_Serviced** (FactTable) - Never refreshed!
- **df_Fact_LaborWIP** (FactTable) - Never refreshed!
- **df_Fact_PartTransactions** (FactTable) - Never refreshed!
- **df_Fact_Part_Transactions** (FactTable) - Never refreshed!
- **df_Transform_Parts** (Transformation) - Never refreshed!
- **df_Transform_Jobs** (Transformation) - Never refreshed!
- **Equipment Service - Data Quality Validation** (AdHoc) - Never refreshed!
- **df_Transform_Vehicles** (Transformation) - Never refreshed!
- **df_Transform_jdis_Part_Information** (Transformation) - Never refreshed!
- **df_jdis_Part_Information_Verification** (AdHoc) - Never refreshed!
- **df_INTRANS_Raw** (RawSource) - Never refreshed!
- **df_Transform_Customers** (Transformation) - Never refreshed!
- **df_Part_Master_Duplicate_Analysis** (AdHoc) - Never refreshed!
- **df_Dim_InvoiceType** (Dimension) - Never refreshed!
- **df_Dim_InvoiceLookup** (Dimension) - Never refreshed!
- **df_Dim_Vehicle** (Dimension) - Never refreshed!
- **df_Dim_SlicerControl** (Dimension) - Never refreshed!
- **df_Dim_BranchFranchise** (Dimension) - Never refreshed!
- **df_CustomerAnatomy_Raw** (RawSource) - Never refreshed!
- **df_Customer_ID_Analysis** (AdHoc) - Never refreshed!
- **df_Dim_Branch** (Dimension) - Never refreshed!
- **df_DealerGroupCode_Analysis** (AdHoc) - Never refreshed!
- **df_Fact_LaborInvoiced** (FactTable) - Never refreshed!
- **df_Fact_InvoiceHeader** (FactTable) - Never refreshed!
- **df_Fact_LaborPunches** (FactTable) - Never refreshed!
- **df_Fact_LaborJobs** (FactTable) - Never refreshed!
- **df_Engaged_Acres** (AdHoc) - Never refreshed!
- **df_Dim_WorkOrderMaster** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderLookup** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderType** (Dimension) - Never refreshed!
- **df_Dim_WorkOrderStatus** (Dimension) - Never refreshed!

---

## Freshness by Category

### AdHoc

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_jdis_Part_Information_Verification | Never | 999999 | [NEVER] Never Refreshed |
| df_Part_Master_Duplicate_Analysis | Never | 999999 | [NEVER] Never Refreshed |
| Equipment Service - Data Quality Validation | Never | 999999 | [NEVER] Never Refreshed |
| df_Engaged_Acres | Never | 999999 | [NEVER] Never Refreshed |
| df_DealerGroupCode_Analysis | Never | 999999 | [NEVER] Never Refreshed |
| df_Customer_ID_Analysis | Never | 999999 | [NEVER] Never Refreshed |
| DF_PartMaster_Snapshot_Weekly | 2026-03-22 06:04:31 | 29.3 | [OK] Fresh |
| DF_PartMaster_Snapshot_Daily | 2026-03-23 07:04:02 | 4.3 | [OK] Fresh |
| df_UniqueCustomer_Lookup | 2026-03-23 09:52:45 | 1.5 | [OK] Fresh |
| df_CustomerLookup | 2026-03-23 09:50:45 | 1.5 | [OK] Fresh |
| df_InTrans_Incremental | 2026-03-23 16:02:46 | -4.7 | [OK] Fresh |

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_Vehicle | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_SlicerControl | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderType | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderStatus | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderMaster | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_WorkOrderLookup | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_InvoiceType | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Branch | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_InvoiceLookup | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_BranchFranchise | Never | 999999 | [NEVER] Never Refreshed |
| df_Dim_Part | 2026-03-23 09:54:13 | 1.5 | [OK] Fresh |
| df_Dim_Customer | 2026-03-23 09:51:43 | 1.5 | [OK] Fresh |
| df_Dim_Date | 2026-03-23 09:51:15 | 1.5 | [OK] Fresh |
| df_Dim_JobCode | 2026-03-23 09:56:53 | 1.4 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-03-23 09:56:53 | 1.4 | [OK] Fresh |
| df_Dim_Technicans | 2026-03-23 09:56:23 | 1.4 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-03-23 09:56:23 | 1.4 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-03-23 15:58:44 | -4.6 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Fact_LaborInvoiced | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_InvoiceHeader | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Part_Transactions | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborJobs | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_Machines_Serviced | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborWIP | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_LaborPunches | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderComprehensive | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderLabor | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderJobs | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WorkOrderHeader | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_PartTransactions | Never | 999999 | [NEVER] Never Refreshed |
| df_Fact_WarrantyClaims | Never | 999999 | [NEVER] Never Refreshed |
| df_FactPartTransactions_Incremental | 2026-03-23 09:59:49 | 1.4 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-03-23 10:03:48 | 1.3 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-03-23 10:05:17 | 1.3 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-03-23 10:04:49 | 1.3 | [OK] Fresh |
| df_Fact_Inventory | 2026-03-23 10:04:51 | 1.3 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-03-23 10:12:14 | 1.2 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-03-23 10:12:07 | 1.2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-03-23 10:07:50 | 1.2 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-03-23 10:11:38 | 1.2 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-03-23 10:12:39 | 1.1 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-03-23 10:16:23 | 1.1 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-03-23 10:15:59 | 1.1 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-03-23 10:15:56 | 1.1 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-03-23 10:15:53 | 1.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-03-23 10:12:39 | 1.1 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-03-23 10:13:10 | 1.1 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-03-23 10:19:36 | 1 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-03-23 10:19:37 | 1 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-03-23 10:19:37 | 1 | [OK] Fresh |
| df_Fact_Transfers | 2026-03-23 10:23:10 | 1 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-03-23 10:25:24 | 0.9 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-03-23 10:25:25 | 0.9 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-03-23 10:25:25 | 0.9 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-03-23 10:26:25 | 0.9 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-03-23 16:18:33 | -4.9 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_CustomerAnatomy_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_INTRANS_Raw | Never | 999999 | [NEVER] Never Refreshed |
| df_Parts_InterbranchTransfer_Raw | 2026-03-23 09:17:45 | 2.1 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-03-23 09:21:15 | 2 | [OK] Fresh |
| df_GlTrans_Raw | 2026-03-23 09:21:45 | 2 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-03-23 09:20:15 | 2 | [OK] Fresh |
| df_Invoice_Raw | 2026-03-23 09:23:15 | 2 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-03-23 09:23:15 | 2 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-03-23 09:30:29 | 1.9 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-03-23 09:30:28 | 1.9 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-03-23 09:35:08 | 1.8 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-03-23 09:30:58 | 1.8 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-03-23 09:34:09 | 1.8 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-03-23 09:34:08 | 1.8 | [OK] Fresh |
| df_INSALORD_Raw | 2026-03-23 09:34:07 | 1.8 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-03-23 09:34:38 | 1.8 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-03-23 09:31:28 | 1.8 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-03-23 09:30:58 | 1.8 | [OK] Fresh |
| df_VhTrans_Raw | 2026-03-23 09:40:20 | 1.7 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-03-23 09:41:50 | 1.7 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-03-23 09:40:51 | 1.7 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-03-23 09:37:39 | 1.7 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-03-23 09:39:50 | 1.7 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-03-23 09:40:21 | 1.7 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-03-23 09:40:21 | 1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-03-23 09:44:33 | 1.6 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-03-23 09:44:33 | 1.6 | [OK] Fresh |
| df_WarClaim_Raw | 2026-03-23 09:44:33 | 1.6 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-03-23 09:44:33 | 1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-03-23 09:44:33 | 1.6 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-03-23 09:45:03 | 1.6 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-03-23 09:44:33 | 1.6 | [OK] Fresh |
| df_Technician_Raw | 2026-03-23 09:44:33 | 1.6 | [OK] Fresh |
| df_CONTACT_Raw | 2026-03-23 09:44:33 | 1.6 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-03-23 16:14:20 | -4.9 | [OK] Fresh |

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

