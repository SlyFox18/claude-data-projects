# Data Freshness Report

**Generated:** 2026-04-24 08:01:25
**Workspace:** LH_Master_Data

---

## Summary

| Status | Count | Percentage |
|--------|-------|------------|
| Fresh | 74 | 84.1% |
| Stale | 0 | 0% |
| Critical |  | 0% |

**Alert Threshold:** 36 hours
**Critical Threshold:** 72 hours

---

## Freshness by Category

### Dimension

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_Dim_BranchUserAccess | 2026-04-23 19:54:02 | 12.1 | [OK] Fresh |
| df_Dim_Part | 2026-04-24 09:51:35 | -1.8 | [OK] Fresh |
| df_Dim_Customer | 2026-04-24 09:49:37 | -1.8 | [OK] Fresh |
| df_Dim_Date | 2026-04-24 09:49:05 | -1.8 | [OK] Fresh |
| df_Dim_Salesperson | 2026-04-24 09:53:45 | -1.9 | [OK] Fresh |
| df_Dim_UniqueCustomers | 2026-04-24 09:53:45 | -1.9 | [OK] Fresh |
| df_Dim_Technicans | 2026-04-24 09:53:45 | -1.9 | [OK] Fresh |
| df_Dim_Branch12_Parts | 2026-04-24 09:53:45 | -1.9 | [OK] Fresh |
| df_Dim_JobCode | 2026-04-24 09:53:45 | -1.9 | [OK] Fresh |
| df_Dim_RepairOrder | 2026-04-24 09:54:45 | -1.9 | [OK] Fresh |

### FactTable

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_FactPartTransactions_Incremental | 2026-04-24 09:57:17 | -1.9 | [OK] Fresh |
| df_Fact_Parts_Details | 2026-04-24 10:02:17 | -2 | [OK] Fresh |
| df_Fact_Inventory | 2026-04-24 10:02:18 | -2 | [OK] Fresh |
| df_Fact_Service_Detail | 2026-04-24 10:00:47 | -2 | [OK] Fresh |
| df_Fact_WorkOrderParts | 2026-04-24 10:02:47 | -2 | [OK] Fresh |
| df_Fact_Service_Invoices | 2026-04-24 10:03:17 | -2 | [OK] Fresh |
| df_Fact_Parts_Invoices | 2026-04-24 10:09:18 | -2.1 | [OK] Fresh |
| df_Fact_LaborJobSummary | 2026-04-24 10:08:11 | -2.1 | [OK] Fresh |
| df_Fact_First_Pass_Fill | 2026-04-24 10:08:47 | -2.1 | [OK] Fresh |
| df_Fact_CustomerPerformance | 2026-04-24 10:07:45 | -2.1 | [OK] Fresh |
| df_Fact_Service_Parts_Detail | 2026-04-24 10:07:14 | -2.1 | [OK] Fresh |
| df_Fact_Invoice_UniqueCustomers | 2026-04-24 10:07:52 | -2.1 | [OK] Fresh |
| df_Fact_PendingInspections | 2026-04-24 10:15:54 | -2.2 | [OK] Fresh |
| df_Fact_PartSales_24Hours | 2026-04-24 10:13:37 | -2.2 | [OK] Fresh |
| df_Fact_Parts_With_Open_Orders | 2026-04-24 10:12:07 | -2.2 | [OK] Fresh |
| df_Fact_Invoice_InventoryAnalysis | 2026-04-24 10:12:37 | -2.2 | [OK] Fresh |
| df_Fact_Branch12_Transactions | 2026-04-24 10:12:19 | -2.2 | [OK] Fresh |
| df_Fact_PartsAdjustments | 2026-04-24 10:12:07 | -2.2 | [OK] Fresh |
| df_Fact_Transfers | 2026-04-24 10:19:54 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_Closed | 2026-04-24 10:16:21 | -2.3 | [OK] Fresh |
| df_Fact_InTrans_UniqueCustomers | 2026-04-24 10:16:30 | -2.3 | [OK] Fresh |
| df_Fact_MDInvoices_NoFreight | 2026-04-24 10:16:26 | -2.3 | [OK] Fresh |
| df_Fact_AdjustmentPairs | 2026-04-24 10:28:11 | -2.4 | [OK] Fresh |
| df_Fact_InSalOrd_InSalPar | 2026-04-24 10:28:11 | -2.4 | [OK] Fresh |
| df_Fact_Equipment_Sales | 2026-04-24 10:25:08 | -2.4 | [OK] Fresh |
| df_Fact_PartsPromo | 2026-04-24 10:28:12 | -2.4 | [OK] Fresh |
| df_Fact_NegativeOnHand_OnHandNoBin | 2026-04-24 10:28:11 | -2.4 | [OK] Fresh |
| df_Fact_Top50_JobCodes | 2026-04-24 10:28:41 | -2.5 | [OK] Fresh |
| df_Fact_Planter_Inspection_Part_Sales | 2026-04-24 10:28:43 | -2.5 | [OK] Fresh |

### RawSource

| Dataflow | Last Refresh | Hours Ago | Status |
|----------|--------------|-----------|--------|
| df_GlTrans_Full_Raw | 2026-04-16 01:32:30 | 198.5 | [CRIT] Critical |
| df_GlTrans_Raw | 2026-04-24 09:21:43 | -1.3 | [OK] Fresh |
| df_WKROFILE_Raw | 2026-04-24 09:20:13 | -1.3 | [OK] Fresh |
| df_Parts_InterbranchTransfer_Raw | 2026-04-24 09:17:43 | -1.3 | [OK] Fresh |
| df_InHist_PmManage_Raw | 2026-04-24 09:21:15 | -1.3 | [OK] Fresh |
| df_Invoice_Raw | 2026-04-24 09:23:43 | -1.4 | [OK] Fresh |
| df_JDIS_PART_INFORMATION_Raw | 2026-04-24 09:27:43 | -1.4 | [OK] Fresh |
| df_InTrans_PartsCounter_Raw | 2026-04-24 09:23:15 | -1.4 | [OK] Fresh |
| df_WKVEHFL_Raw | 2026-04-24 09:29:58 | -1.5 | [OK] Fresh |
| df_WKRODESC_Raw | 2026-04-24 09:30:59 | -1.5 | [OK] Fresh |
| df_WKINVREG_Raw | 2026-04-24 09:30:31 | -1.5 | [OK] Fresh |
| df_WKMECHWK_Raw | 2026-04-24 09:31:00 | -1.5 | [OK] Fresh |
| df_WKOTHSUB_Raw | 2026-04-24 09:30:58 | -1.5 | [OK] Fresh |
| df_INSALORD_Raw | 2026-04-24 09:34:16 | -1.5 | [OK] Fresh |
| df_InMaster_Raw | 2026-04-24 09:31:59 | -1.5 | [OK] Fresh |
| df_INSALPAR_Raw | 2026-04-24 09:34:15 | -1.5 | [OK] Fresh |
| df_RepairOrderDetail_Raw | 2026-04-24 09:34:16 | -1.5 | [OK] Fresh |
| df_TechnicianPunchedTime_Raw | 2026-04-24 09:39:25 | -1.6 | [OK] Fresh |
| df_TechnicianPunchedDetail_Raw | 2026-04-24 09:35:17 | -1.6 | [OK] Fresh |
| df_VHSTOCK_Raw | 2026-04-24 09:34:45 | -1.6 | [OK] Fresh |
| df_VhTrans_Raw | 2026-04-24 09:38:25 | -1.6 | [OK] Fresh |
| df_VhStockAccess_Raw | 2026-04-24 09:38:26 | -1.6 | [OK] Fresh |
| df_TechnicianInvoiceDetail_Raw | 2026-04-24 09:35:44 | -1.6 | [OK] Fresh |
| df_TechnicianAttendance_Raw | 2026-04-24 09:37:55 | -1.6 | [OK] Fresh |
| df_Insalpar_Audit_Raw | 2026-04-24 09:38:25 | -1.6 | [OK] Fresh |
| df_TechnicianInvoice_Raw | 2026-04-24 09:38:26 | -1.6 | [OK] Fresh |
| df_TechnicianEfficiency_Raw | 2026-04-24 09:38:29 | -1.6 | [OK] Fresh |
| df_ARMASTER_Raw | 2026-04-24 09:42:38 | -1.7 | [OK] Fresh |
| df_Branch_Name_Raw | 2026-04-24 09:42:13 | -1.7 | [OK] Fresh |
| df_ArMaster_Contact_Raw | 2026-04-24 09:42:07 | -1.7 | [OK] Fresh |
| df_ArMaster_Customer_Raw | 2026-04-24 09:42:38 | -1.7 | [OK] Fresh |
| df_CONTACT_Raw | 2026-04-24 09:42:08 | -1.7 | [OK] Fresh |
| df_Technician_Raw | 2026-04-24 09:42:07 | -1.7 | [OK] Fresh |
| df_WarClaim_Raw | 2026-04-24 09:42:07 | -1.7 | [OK] Fresh |
| df_BranchOperational_Raw | 2026-04-24 09:41:37 | -1.7 | [OK] Fresh |
| df_WARSUBCI_LABOUR_Raw | 2026-04-24 09:42:08 | -1.7 | [OK] Fresh |

---

**CSV Report:** `Dataflow-Freshness-Report.csv`

